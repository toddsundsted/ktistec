require "../../task"
require "./mixins/fetcher"
require "../../activity_pub/actor"
require "../../activity_pub/object"
require "../../activity_pub/collection"
require "../../../rules/content_rules"

class Task
  # Fetch a thread.
  #
  class Fetch::Thread < Task
    include Task::ConcurrentTask
    include Fetcher

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
        if node.in?(nodes)
          raise DuplicateNodeError.new(%Q|Duplicate node: #{node.id}|)
        end
        nodes << node
        self
      end

      def prioritize!
        nodes.sort_by!(&.delta).dup
      end

      class DuplicateNodeError < Exception
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
          state << State::Node.new(object.id.not_nil!)
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

    # Finds an existing task or instantiates a new task.
    #
    # If `thread` (or `subject_iri`) is passed as an option, search
    # for the root of the thread, and use that value. This ensures
    # that new tasks always point at roots.
    #
    def self.find_or_new(**options)
      if (thread = options[:thread]?) && (ephemeral = ActivityPub::Object.new(iri: thread).ancestors.last?)
        options = options.merge({thread: ephemeral.thread})
        find?(**options) || new(**options)
      elsif (subject_iri = options[:subject_iri]?) && (ephemeral = ActivityPub::Object.new(iri: subject_iri).ancestors.last?)
        options = options.merge({subject_iri: ephemeral.thread})
        find?(**options) || new(**options)
      else
        find?(**options) || new(**options)
      end
    end

    # Sets the task to complete.
    #
    def complete!
      update_property(:complete, true)
    end

    # Fetches objects in the thread.
    #
    # On each invocation, performs at most `maximum` (default 100)
    # fetches/network requests for new objects.
    #
    def perform(maximum = 100)
      # look for replies that were added by some other means since
      # the last run. handles the regular arrival of objects via
      # ActivityPub.
      if (last_attempt_at = self.last_attempt_at)
        ActivityPub::Object.where("thread = ? AND created_at > ?", thread, last_attempt_at).each do |reply|
          node = State::Node.new(reply.id.not_nil!)
          state << node unless state.nodes.includes?(node)
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
          # It's possible to have two tasks following two parts of a
          # (currently) disconnected thread (the joint root has not
          # yet been discovered/fetched). As soon as one task
          # discovers the root it destroys the other task. If this
          # task was the one destroyed, stop working.
          if gone?
            Log.info { "perform [#{id}] - gone - stopping task" }
            break
          end
          Log.info { "perform [#{id}] - iteration: #{count + 1}, horizon: #{state.nodes.size} items" }
          object = fetch_one(state.prioritize!)
          break unless object
          ContentRules.new.run do
            assert ContentRules::CheckFollowFor.new(source, object)
          end
          count += 1
        end
      ensure
        Log.info { "perform [#{id}] - complete - #{count} fetched" }
        self.next_attempt_at =
          if count < 1 && !continuation              # none fetched
            calculate_next_attempt_at(Horizon::FarFuture)
          elsif count < maximum                      # some fetched
            calculate_next_attempt_at(Horizon::NearFuture)
          else                                       # maximum number fetched
            calculate_next_attempt_at(Horizon::ImmediateFuture)
          end
      end
    end

    # Fetches up toward the root.
    #
    private def fetch_up
      100.times do # for safety, cap loops
        Log.info { "fetch_up [#{id}] - iri: #{self.thread}" }
        fetched, object = find_or_fetch_object(self.thread)
        state.root_object = object.id if object && object.root?
        break if object.nil? || (object.root? && !fetched)
        self.thread = object.thread.not_nil!
        state << State::Node.new(object.id.not_nil!)
        return object if fetched
      end
    end

    property been_fetched : Array(String) = [] of String

    # Fetches out through the horizon.
    #
    private def fetch_out(horizon)
      while (node = horizon.shift?)
        object = ActivityPub::Object.find?(node.id)
        now = Time.utc
        if object
          if object.local?
            Log.info { "fetch_out [#{id}] - iri: #{object.iri}" }
            node.last_attempt_at = now
            ids = state.nodes.map(&.id)
            size =
              ActivityPub::Object.where(in_reply_to_iri: object.iri).count do |reply|
                unless reply.id.in?(ids)
                  node.last_success_at = now
                  state << State::Node.new(reply.id.not_nil!)
                end
              end
            Log.info { "fetch_out [#{id}] - #{size} items" }
          else
            node.last_attempt_at = now
            ids = state.nodes.map(&.id)
            if state.cache.presence && state.cached_object != node.id
              Log.info { "fetch_out [#{id}] - cache invalidated - #{state.cache.try(&.size)} items remaining" }
              state.cache = nil
            end
            state.cache.presence || begin
              # only fetch a collection once per run
              next if been_fetched.includes?(object.iri)
              been_fetched << object.iri
              state.cached_object = node.id
              state.cache =
                if (temporary = ActivityPub::Object.dereference?(source, object.iri, ignore_cached: true))
                  Log.info { "fetch_out [#{id}] - iri: #{object.iri}" }
                  if (replies = temporary.replies?(source, dereference: true))
                    if (iris = replies.all_item_iris(source))
                      iris
                    end
                  end
                end
              unless (size = state.cache.try(&.size))
                Log.info { "fetch_out [#{id}] - iri: #{object.iri}" }
                size = 0
              end
              Log.info { "fetch_out [#{id}] - #{size} items" }
            end
            while (cache = state.cache) && (item = cache.shift?)
              fetched, object = find_or_fetch_object(item)
              next if object.nil?
              unless object.id.in?(ids)
                node.last_success_at = now
                state << State::Node.new(object.id.not_nil!)
                return object if fetched
              end
            end
          end
        end
      end
    end

    # Fetches one new object in the thread.
    #
    # Explores the thread, and fetches and returns a new object or
    # `nil` if no new object is fetched.
    #
    private def fetch_one(horizon)
      if !state.root_object && (object = fetch_up)
        object
      else
        fetch_out(horizon)
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
