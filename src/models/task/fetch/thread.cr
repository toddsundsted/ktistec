require "../../task"
require "../../activity_pub/actor"
require "../../activity_pub/object"

class Task
  # Fetch a thread.
  #
  class Fetch::Thread < Task
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
