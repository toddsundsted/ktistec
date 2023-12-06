require "../../task"
require "../../activity_pub/actor"
require "../../activity_pub/object"
require "../../../rules/content_rules"

class Task
  # Fetch a thread.
  #
  class Fetch::Thread < Task
    include Task::ConcurrentTask

    belongs_to source, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri
    validates(source) { "missing: #{source_iri}" unless source? }

    # Identifies a thread.
    #
    # This value may change as the thread is extended toward its root.
    #
    derived thread : String, aliased_to: subject_iri
    validates(thread) { "must not be blank" if thread.blank? }

    # Finds an existing task or instantiates a new one.
    #
    def self.find_or_new(**options)
      find?(**options) || new(**options)
    end

    # Sets the task to complete.
    #
    def complete!
      update_property(:complete, true)
    end

    # Fetches objects in the thread.
    #
    # On each invocation, performs at most `maximum` (default 10)
    # fetches/network requests for new objects.
    #
    def perform(maximum = 10)
      count = 0
      none_fetched = true
      last = nil
      maximum.times do
        count += 1
        object = fetch_one
        none_fetched = false if object
        last = object if object
        break unless object
      end
    ensure
      self.next_attempt_at =
        if none_fetched                  # none fetched
          4.hours.from_now
        elsif count && count < maximum   # some fetched
          1.hour.from_now
        else                             # maximum number fetched
          5.seconds.from_now
        end
      if last && last.root?
        ContentRules.new.run do
          assert ContentRules::CheckFollowFor.new(source, last)
        end
      end
    end

    # Finds or fetches an object.
    #
    # Returns an indicator of whether the object was fetched or not,
    # and the object.
    #
    # Saves/caches fetched objects.
    #
    private def find_or_fetch_object(iri)
      fetched = false
      if (object = ActivityPub::Object.dereference?(source, iri, include_deleted: true))
        if object.new_record?
          fetched = true
          # fetch the author, too
          object.attributed_to?(source, dereference: true)
          object.save
        end
      end
      {fetched, object}
    end

    # Fetches one new object in the thread.
    #
    # Explores the thread, and fetches and returns a new object or
    # `nil` if no new object is fetched.
    #
    private def fetch_one
      ## work toward the root
      last = nil
      100.times do # for safety, cap loops
        fetched, object = find_or_fetch_object(self.thread)
        break if object.nil? || (object.root? && !fetched) || object == last
        self.thread = object.thread.not_nil!
        return object if fetched
        last = object
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
