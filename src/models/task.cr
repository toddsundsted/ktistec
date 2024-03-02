require "../framework/ext/sqlite3"
require "../framework/model"
require "../framework/model/**"
require "../workers/task_worker"

# Background task.
#
# By default, background tasks are processed sequentially.
#
class Task
  # Marker for a task that may be processed concurrently.
  #
  module ConcurrentTask
  end

  include Ktistec::Model(Common, Polymorphic)

  @@table_name = "tasks"

  # The table includes a column named "failures" that subclasses can
  # define and use to serialize information about task failures.

  # The table includes a column named "state" that subclasses can
  # define and use to serialize information about task state.

  @@table_columns = ["failures", "state"]

  @[Persistent]
  property source_iri : String

  @[Persistent]
  property subject_iri : String

  @[Persistent]
  @[Insignificant]
  property running : Bool { false }

  @[Persistent]
  @[Insignificant]
  property complete : Bool { false }

  @[Persistent]
  @[Insignificant]
  property backtrace : Array(String)?

  @[Persistent]
  property next_attempt_at : Time?

  @[Persistent]
  property last_attempt_at : Time?

  # Indicates whether or not the task is gone.
  #
  # Typically, this means that the task was saved but has been
  # destroyed. Destroying a running task is a lightweight signal that
  # the task should terminate itself.
  #
  def gone?
    !(@id && Task.find?(@id))
  end

  def runnable?
    !running && !complete && !backtrace
  end

  def past_due?(now = Time.utc)
    next_attempt_at.nil? || next_attempt_at.try(&.<(now))
  end

  private def self.compare_times(a : Time?, b : Time?)
    if a == b
      0
    elsif a && b
      a <=> b
    elsif a
      1
    elsif b
      -1
    end
  end

  def self.scheduled(now = Time.utc, reserve = false)
    if reserve
      query = <<-SQL
         UPDATE tasks
            SET running = 1
          WHERE running = 0 AND complete = 0 AND backtrace IS NULL
            AND (next_attempt_at IS NULL OR next_attempt_at < ?)
      RETURNING #{columns}
      SQL
      query_all(query, now).sort do |a, b|
        # RETURNING does not provide a means to guarantee ordering
        if (result = compare_times(a.next_attempt_at, b.next_attempt_at)) == 0
          compare_times(a.created_at, b.created_at)
        else
          result
        end
      end
    else
      query = <<-SQL
          SELECT #{columns}
          FROM tasks
         WHERE running = 0 AND complete = 0 AND backtrace IS NULL
           AND (next_attempt_at IS NULL OR next_attempt_at < ?)
      ORDER BY next_attempt_at, id
      SQL
      query_all(query, now)
    end
  end

  def schedule(@next_attempt_at = nil)
    raise "Not runnable" unless runnable? || complete
    self.complete = false
    TaskWorker.schedule(self)
  end

  def perform
    raise NotImplementedError.new("Task#perform must be implemented in each subclass")
  end
end
