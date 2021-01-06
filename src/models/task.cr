require "../framework/model"
require "../framework/model/**"

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

  @[Persistent]
  property running : Bool { false }

  @[Persistent]
  property complete : Bool { false }

  @[Persistent]
  property backtrace : Array(String)?

  @[Persistent]
  property next_attempt_at : Time?

  @[Persistent]
  property last_attempt_at : Time?

  def runnable?
    !running && !complete && !backtrace
  end

  def past_due?(now = Time.utc)
    next_attempt_at.nil? || next_attempt_at.try(&.<(now))
  end

  def self.scheduled(now = Time.utc)
    query = <<-SQL
      running = 0 AND complete = 0 AND backtrace IS NULL
      AND (next_attempt_at IS NULL OR next_attempt_at < ?)
      ORDER BY next_attempt_at, created_at
    SQL
    where(query, now)
  end

  def schedule(@next_attempt_at = nil)
    raise "Not runnable" unless runnable?
    save
  end

  def perform
    raise NotImplementedError.new("Task#perform must be implemented in each subclass")
  end

  @[Persistent]
  property state : String?
end
