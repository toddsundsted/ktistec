require "../../task"
require "./mixins/fetcher"
require "../../activity_pub/actor"
require "../../activity_pub/object"
require "../../../framework/topic"
require "../../activity_pub/collection"
require "../../../rules/content_rules"
require "../../../views/view_helper"

class Task
  # Fetch a thread.
  #
  class Fetch::Thread < Task
    include Task::ConcurrentTask
    include Fetcher

    Log = ::Log.for(self)

    # Implements a prioritized queue of nodes on the thread horizon.
    #
    class State
      include JSON::Serializable

      # A node in the prioritized queue.
      #
      class Node
        include JSON::Serializable

        property id : Int64
        property last_attempt_at : Time
        property last_success_at : Time

        def_equals(:id)

        def initialize(@id, @last_attempt_at = Time::UNIX_EPOCH, @last_success_at = Time::UNIX_EPOCH)
        end

        def delta
          last_attempt_at - last_success_at
        end
      end

      property nodes : Array(Node)

      # Root object of thread.
      property root_object : Int64?

      # Object for which replies are cached.
      property cached_object : Int64?

      # Cached replies.
      property cache : Array(String)?

      # Count of successive failures to fetch new objects.
      property failures : Int32 = 0

      def initialize(@nodes = [] of Node)
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
        # when instantiated, load the state up with
        # any already cached objects in the thread.
        ephemeral = ActivityPub::Object.new(iri: thread)
        ephemeral.thread(for_actor: source).each do |object|
          node = State::Node.new(object.id.not_nil!)
          state << node unless state.includes?(node)
        end
      end
    end

    # Identifies the actor following the thread.
    #
    belongs_to source, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(source) { "missing: #{source_iri}" unless source? }

    # Identifies a thread.
    #
    # This value may change as the thread is extended toward its root.
    #
    derived thread : String, aliased_to: subject_iri
    validates(thread) { "must not be blank" if thread.blank? }

    # Finds the best root object.
    #
    # This will be the actual root object, if the root object has been
    # fetched and is cached.  Otherwise, it will be an object in the
    # incomplete thread.
    #
    def best_root
      ActivityPub::Object.where("thread = ? AND likelihood(in_reply_to_iri IS NULL, 0.25) LIMIT 1", thread).first? ||
        ActivityPub::Object.where("thread = ? AND in_reply_to_iri = thread LIMIT 1", thread).first? ||
        raise NotFound.new("ActivityPub::Object thread=#{thread}: not found")
    end

    # Finds an existing task or instantiates a new task.
    #
    # If `thread` (or `subject_iri`) is passed as an option, search
    # for the root of the thread, and use that value. This ensures
    # that new tasks always point at roots.
    #
    def self.find_or_new(**options)
      if (thread = options[:thread]?) && (ephemeral = ActivityPub::Object.new(iri: thread).ancestors.last?)
        super(**options.merge({thread: ephemeral.thread}))
      elsif (subject_iri = options[:subject_iri]?) && (ephemeral = ActivityPub::Object.new(iri: subject_iri).ancestors.last?)
        super(**options.merge({subject_iri: ephemeral.thread}))
      else
        super(**options)
      end
    end

    # :ditto:
    def self.find_or_new(options)
      if (thread = options["thread"]?) && (ephemeral = ActivityPub::Object.new(iri: thread).ancestors.last?)
        super(options.merge({"thread" => ephemeral.thread}))
      elsif (subject_iri = options["subject_iri"]?) && (ephemeral = ActivityPub::Object.new(iri: subject_iri).ancestors.last?)
        super(options.merge({"subject_iri" => ephemeral.thread}))
      else
        super(options)
      end
    end

    # Sets the task to complete.
    #
    def complete!
      update_property(:complete, true)
    end

    private property interrupted : Bool = false

    # Indicates whether the task was asynchronously set as complete.
    #
    def interrupted?
      @interrupted ||= self.class.find(self.id).complete
    end

    # Fetches objects in the thread.
    #
    # On each invocation, performs at most `maximum` (default 100)
    # fetches/network requests for new objects.
    #
    def perform(maximum = 100)
      Ktistec::Topic{thread}.notify_subscribers
      # look for replies that were added by some other means since
      # the last run. handles the regular arrival of objects via
      # ActivityPub.
      if (last_attempt_at = self.last_attempt_at)
        ActivityPub::Object.where("thread = ? AND created_at > ?", thread, last_attempt_at).each do |reply|
          node = State::Node.new(reply.id.not_nil!)
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
          # It's possible to have two tasks following two parts of a
          # (currently) disconnected thread (the joint root has not
          # yet been discovered/fetched). As soon as one task
          # discovers the root it destroys the other task. If this
          # task was the one destroyed, stop working.
          if gone?
            Log.debug { "perform [#{id}] - gone - stopping task" }
            break
          end
          Log.debug { "perform [#{id}] - iteration: #{count + 1}, horizon: #{state.nodes.size} items" }
          object =
            if !state.root_object && (temporary = fetch_up)
              temporary
            else
              fetch_out(state.prioritize!)
            end
          break unless object
          ContentRules.new.run do
            assert ContentRules::CheckFollowFor.new(source, object)
          end
          Ktistec::Topic{thread}.notify_subscribers(object.id.to_s)
          count += 1
        end
      ensure
        duration = (Time.monotonic - start).total_seconds
        duration = sprintf("%.3f", duration)
        if interrupted
          Log.debug { "perform [#{id}] - interrupted! - #{duration} seconds, #{count} fetched" }
          # ensure that when this instance is eventually saved, it too
          # is set as complete.
          self.complete = true
        else
          Log.debug { "perform [#{id}] - complete - #{duration} seconds, #{count} fetched" }
        end
        self.next_attempt_at =
          if count < 1 && !continuation && !interrupted            # none fetched
            calculate_next_attempt_at(Horizon::FarFuture)
          elsif count < maximum && !interrupted                    # some fetched
            calculate_next_attempt_at(Horizon::NearFuture)
          else                                                     # maximum number fetched
            calculate_next_attempt_at(Horizon::ImmediateFuture)
          end
      end
    end

    def after_save
      Ktistec::Topic{thread}.notify_subscribers
    end

    # Fetches up toward the root.
    #
    private def fetch_up
      100.times do # for safety, cap loops
        break if interrupted?
        Log.trace { "fetch_up [#{id}] - iri: #{self.thread}" }
        fetched, object = find_or_fetch_object(self.thread, include_deleted: true)
        state.root_object = object.id if object && object.root?
        break if object.nil?
        self.thread = object.thread.not_nil!
        node = State::Node.new(object.id.not_nil!)
        state << node unless state.includes?(node)
        break if object.root? && !fetched
        return object if fetched
      end
    end

    property been_fetched : Array(String) = [] of String

    # Fetches out through the horizon.
    #
    private def fetch_out(horizon)
      # Check to see if the task has been interrupted/asynchronously
      # set as complete. This is how a controller can signal to the
      # task that its work is done.
      while (node = horizon.shift?) && !interrupted?
        object = ActivityPub::Object.find?(node.id)
        now = Time.utc
        if object
          if object.local?
            Log.trace { "fetch_out [#{id}] - iri: #{object.iri}" }
            node.last_attempt_at = now
            size =
              ActivityPub::Object.where(in_reply_to_iri: object.iri).count do |reply|
                new = State::Node.new(reply.id.not_nil!)
                unless state.includes?(new)
                  node.last_success_at = now
                  state << new
                end
              end
            Log.trace { "fetch_out [#{id}] - #{size} items" }
          else
            node.last_attempt_at = now
            if state.cache.presence && state.cached_object != node.id
              Log.trace { "fetch_out [#{id}] - cache invalidated - #{state.cache.try(&.size)} items remaining" }
              state.cache = nil
            end
            state.cache.presence || begin
              # only fetch a collection once per run
              next if been_fetched.includes?(object.iri)
              been_fetched << object.iri
              state.cached_object = node.id
              state.cache =
                if (temporary = ActivityPub::Object.dereference?(source, object.iri, ignore_cached: true))
                  Log.trace { "fetch_out [#{id}] - iri: #{object.iri}" }
                  if (replies = temporary.replies?) || ((replies_iri = temporary.replies_iri) && (replies = ActivityPub::Collection.dereference?(source, replies_iri)))
                    if (iris = replies.all_item_iris(source))
                      iris
                    end
                  end
                end
              unless (size = state.cache.try(&.size))
                Log.trace { "fetch_out [#{id}] - iri: #{object.iri}" }
                size = 0
              end
              Log.trace { "fetch_out [#{id}] - #{size} items" }
            end
            while (cache = state.cache) && (item = cache.shift?)
              fetched, object = find_or_fetch_object(item)
              next if object.nil?
              new = State::Node.new(object.id.not_nil!)
              unless state.includes?(new)
                node.last_success_at = now
                state << new
                return object if fetched
              end
            end
          end
        end
      end
    end

    # Merges tasks.
    #
    # Should be used in places where an object's thread property is
    # changed. Ensures that only one task exists for a thread.
    #
    def self.merge_into(from, into)
      if from != into
        where(thread: from).each do |task|
          unless find?(source: task.source, thread: into)
            task.assign(thread: into).save
          else
            task.destroy
          end
        end
      end
    end

    # Returns the path to the thread index page.
    #
    def path_to
      Ktistec::ViewHelper.remote_thread_path(best_root, anchor: false)
    end
  end
end

# updates the `thread` property when an object is saved. patching
# `Object` like this pulls the explicit dependency out of its source
# code.

module ActivityPub
  class Object
    def after_save
      previous_def
      Task::Fetch::Thread.merge_into(self.iri, self.thread)
    end
  end
end
