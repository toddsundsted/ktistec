require "../../task"
require "../../activity_pub/actor"
require "../../activity_pub/object"
require "../../../rules/content_rules"

class Task
  # Fetch a hashtag.
  #
  class Fetch::Hashtag < Task
    include Task::ConcurrentTask

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

    # Fetches objects tagged with the hashtag `name`.
    #
    # On each invocation, performs at most `maximum` (default 10)
    # fetches/network requests for new objects.
    #
    def perform(maximum = 10)
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
      begin
        maximum.times do
          Log.info { "perform [#{id}] - iteration: #{count + 1}, horizon: #{state.nodes.size} items" }
          object = fetch_one(state.prioritize!)
          break unless object
          count += 1
        end
      ensure
        Log.info { "perform [#{id}] - complete - #{count} fetched" }
        random = Random::DEFAULT
        self.next_attempt_at =
          if count < 1 && !continuation              # none fetched => far future
            state.failures += 1
            base = 2 ** (state.failures + 1)
            offset = base // 4
            min = base - offset
            max = base + offset
            random.rand(min..max).hours.from_now
          elsif count < maximum                      # some fetched => near future
            state.failures = 0
            random.rand(45..75).minutes.from_now
          else                                       # maximum number fetched => immediate future
            state.failures = 0
            random.rand(4..6).seconds.from_now
          end
      end

      if (hashtag = Tag::Hashtag.where("name = ? ORDER BY created_at DESC LIMIT 1", name).first?) && (recent = ActivityPub::Object.find?(hashtag.subject_iri))
        if (count < 1 && continuation) || (count > 0 && count < maximum)
          ContentRules.new.run do
            assert ContentRules::CheckFollowFor.new(source, recent)
          end
        end
      end
    end

    # Temporary cache of undereferenceable object IRIs. The same
    # object is often found in more than one (sometimes all) hashtag
    # collections. This prevents spending resources on an object when
    # it has failed once and is likely to fail again. The cache is not
    # persisted across invocations of `perform`.
    #
    @bad_object_iris = [] of String

    # Finds or fetches an object.
    #
    # Returns an indicator of whether the object was fetched or not,
    # and the object.
    #
    # Saves/caches fetched objects.
    #
    private def find_or_fetch_object(iri)
      fetched = false
      if !iri.in?(@bad_object_iris) && (object = ActivityPub::Object.dereference?(source, iri, include_deleted: true))
        if object.new_record?
          fetched = true
          # fetch the author, too
          object.attributed_to?(source, dereference: true)
          object.save
        end
      else
        @bad_object_iris << iri
      end
      {fetched, object}
    end

    # Fetches one new object tagged with the hashtag.
    #
    # Fetches and returns a new object or `nil` if no new object is
    # fetched.
    #
    private def fetch_one(horizon)
      while (node = horizon.shift?)
        now = Time.utc
        node.last_attempt_at = now
        if state.cache.presence && state.cached_collection != node.href
          Log.info { "fetch_one [#{id}] - cache invalidated - #{state.cache.try(&.size)} items remaining" }
          state.cache = nil
        end
        state.cache.presence || begin
          state.cached_collection = node.href
          state.cache = Array(String).new.tap do |items|
            if (collection = ActivityPub::Collection.dereference?(source, node.href))
              if (iris = collection.items_iris)
                Log.info { "fetch_one [#{id}] - iri: #{collection.iri}" }
                items.concat(iris)
              elsif (uri = URI.parse(node.href)).path =~ %r|^/tags/([^/]+)$|
                url = uri.resolve("/api/v1/timelines/tag/#{$1}").to_s
                headers = HTTP::Headers{"Accept" => "application/json"}
                Ktistec::Open.open?(source, url, headers) do |response|
                  Log.info { "fetch_one (API) [#{id}] - iri: #{url}" }
                  Array(JSON::Any).from_json(response.body).each do |item|
                    if (item = item.as_h?) && (item = item.dig?("uri")) && (item = item.as_s?)
                      items << item
                    end
                  end
                rescue JSON::Error
                  Log.warn { "fetch_one (API) [#{id}] - JSON response parse error" }
                end
              end
            end
            Log.info { "fetch_one [#{id}] - #{items.size} items" }
          end
        end
        if (cache = state.cache.presence)
          while (item = cache.shift?)
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
    end
  end
end
