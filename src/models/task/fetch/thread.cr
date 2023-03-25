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
  end
end
