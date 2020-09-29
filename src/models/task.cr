require "../framework/model"

# Asynchronous task.
#
class Task
  include Ktistec::Model(Common, Polymorphic)

  @@table_name = "tasks"

  @[Persistent]
  property source_iri : String

  @[Persistent]
  property subject_iri : String

  @[Persistent]
  property failures : Array(Failure) { [] of Failure }

  struct Failure
    include JSON::Serializable

    property description : String

    property timestamp : Time

    def initialize(@description, @timestamp = Time.utc)
    end
  end

  def perform
    raise NotImplementedError.new("Task#perform must be implemented in each subclass")
  end
end
