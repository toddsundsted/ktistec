require "../../task"
require "./mixins/fetcher"
require "../../activity_pub/actor"
require "../../activity_pub/object"
require "../../relationship/content/follow/hashtag"
require "../../../framework/topic"
require "../../../rules/content_rules"
require "../../../views/view_helper"

class Task
  # Fetch a hashtag.
  #
  class Fetch::Hashtag < Task
    include Task::ConcurrentTask
    include Fetcher

    Log = ::Log.for(self)

    # Implements a prioritized queue of nodes on the search horizon.
    #
    class State
      include JSON::Serializable

      # A node in the prioritized queue.
      #
      class Node
        include JSON::Serializable

        property href : String
        property last_attempt_at : Time
        property last_success_at : Time

        def_equals(:href)

        def initialize(href, @last_attempt_at = Time::UNIX_EPOCH, @last_success_at = Time::UNIX_EPOCH)
          @href = URI.parse(href.downcase).normalize.to_s
        end

        def delta
          last_attempt_at - last_success_at
        end
      end

      property nodes = [] of Node

      # Collection for which objects are cached.
      property cached_collection : String?

      # Cached objects.
      property cache : Array(String)?

      # Count of successive failures to fetch new objects.
      property failures : Int32 = 0

      def initialize
      end

      def <<(node : Node)
        nodes << node
        self
      end

      def includes?(node : Node)
        nodes.includes?(node)
      end

      def prioritize!
        nodes.sort_by!(&.delta).dup
      end

      def last_success_at
        nodes.map(&.last_success_at).select(&.!=(Time::UNIX_EPOCH)).max?
      end
    end

    @[Persistent]
    @[Insignificant]
    property state : State do
        State.new.tap do |state|
          Tag::Hashtag.where(name: name).map(&.href.presence).compact.each do |href|
            node = State::Node.new(href)
            state << node unless state.includes?(node)
          end
        end
    end

    # Identifies the actor following the hashtag.
    #
    belongs_to source, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(source) { "missing: #{source_iri}" unless source? }

    # Identifies a hashtag.
    #
    derived name : String, aliased_to: subject_iri
    validates(name) { "must not be blank" if name.blank? }

    # Indicates whether a follow relationship exists for the hashtag.
    #
    def follow?
      Relationship::Content::Follow::Hashtag.count(actor: source, name: name) > 0
    end

    # Fetches objects tagged with the hashtag `name`.
    #
    # On each invocation, performs at most `maximum` (default 100)
    # fetches/network requests for new objects.
    #
    def perform(maximum = 100)
      # notify subscribers when the task starts running, because the
      # transition to `running = true` does not trigger a lifecycle
      # callback.
      Ktistec::Topic{path_to}.notify_subscribers
      # look for hashtags that were added by some other means since
      # the last run. handles the regular arrival of objects via
      # ActivityPub.
      if (last_attempt_at = self.last_attempt_at)
        Tag::Hashtag.where("name = ? AND created_at > ?", name, last_attempt_at).map(&.href.presence).compact.each do |href|
          node = State::Node.new(href)
          state << node unless state.includes?(node)
        end
      end
      # if this task last ran in the immediate past, assume the
      # maximum number of objects were fetched and this is a
      # "continuation" of that run. this handles the edge case where
      # the last run fetched exactly the maximum number of objects
      # and there are no remaining objects this run.
      continuation =
        if (last_attempt_at = self.last_attempt_at)
          last_attempt_at > 20.minutes.ago
        else
          false
        end
      count = 0
      start = Time.monotonic
      begin
        maximum.times do
          Log.debug { "perform [#{id}] - hashtag: #{name}, iteration: #{count + 1}, horizon: #{state.nodes.size} items" }
          object = fetch_one(state.prioritize!)
          break unless object
          ContentRules.new.run do
            assert ContentRules::CheckFollowFor.new(source, object)
          end
          Ktistec::Topic{path_to}.notify_subscribers(object.id.to_s)
          count += 1
        end
      ensure
        duration = (Time.monotonic - start).total_seconds
        duration = sprintf("%.3f", duration)
        if interrupted
          Log.debug { "perform [#{id}] - hashtag: #{name} - interrupted! - #{duration} seconds, #{count} fetched" }
          # ensure that when this instance is eventually saved, it too
          # is set as complete.
          self.complete = true
        else
          Log.debug { "perform [#{id}] - hashtag: #{name} - complete - #{duration} seconds, #{count} fetched" }
        end
        set_next_attempt_at(maximum, count, continuation)
      end
    end

    def after_save
      Ktistec::Topic{path_to}.notify_subscribers
    end

    property been_fetched = Set(String).new

    # Fetches one new object tagged with the hashtag.
    #
    # Fetches and returns a new object or `nil` if no new object is
    # fetched.
    #
    private def fetch_one(horizon)
      # Check to see if the task has been interrupted/asynchronously
      # set as complete. This is how a controller can signal to the
      # task that its work is done.
      while (node = horizon.shift?) && !interrupted?
        now = Time.utc
        node.last_attempt_at = now
        if state.cache.presence && state.cached_collection != node.href
          Log.trace { "fetch_one [#{id}] - cache invalidated - #{state.cache.try(&.size)} items remaining" }
          state.cache = nil
        end
        state.cache.presence || begin
          # only fetch a collection once per run
          next if been_fetched.includes?(node.href)
          been_fetched << node.href
          state.cached_collection = node.href
          state.cache =
            if (collection = ActivityPub::Collection.dereference?(source, node.href))
              if (iris = collection.all_item_iris(source))
                Log.trace { "fetch_one [#{id}] - iri: #{collection.iri}" }
                iris
              elsif (uri = URI.parse(node.href)).path =~ %r|^/tags/([^/]+)$|
                url = uri.resolve("/api/v1/timelines/tag/#{$1}").to_s
                headers = HTTP::Headers{"Accept" => "application/json"}
                Ktistec::Open.open?(source, url, headers) do |response|
                  Log.trace { "fetch_one [#{id}] - iri: #{url}" }
                  Array(JSON::Any).from_json(response.body).reduce([] of String) do |items, item|
                    if (item = item.as_h?) && (item = item.dig?("uri")) && (item = item.as_s?)
                      items << item
                    end
                    items
                  end
                rescue JSON::Error
                  Log.debug { "fetch_one [#{id}] - JSON response parse error" }
                end
              end
            end
          unless (size = state.cache.try(&.size))
            Log.trace { "fetch_one [#{id}] - iri: #{node.href}" }
            size = 0
          end
          Log.trace { "fetch_one [#{id}] - #{size} items" }
        end
        while (cache = state.cache) && (item = cache.shift?)
          # only fetch an object once per run
          next if been_fetched.includes?(item)
          been_fetched << item
          fetched, object = find_or_fetch_object(item)
          next if object.nil?
          if (hashtags = object.hashtags)
            hashtags.select{ |h| h.name.downcase == name }.map(&.href).compact.each do |href|
              new = State::Node.new(href)
              state << new unless state.includes?(new)
            end
          end
          if fetched
            node.last_success_at = now
            return object
          end
        end
      end
    end

    # Returns the path to the hashtag index page.
    #
    def path_to
      Ktistec::ViewHelper.hashtag_path(name)
    end
  end
end
