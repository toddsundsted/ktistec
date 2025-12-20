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
    # Returns the name assigned to the associated fiber.
    #
    def fiber_name
      "#{self.class}-#{self.id}"
    end

    # Returns the associated fiber.
    #
    def fiber
      fiber_name = self.fiber_name
      Fiber.unsafe_each do |fiber|
        return fiber if fiber.name == fiber_name
      end
    end
  end

  include Ktistec::Model
  include Ktistec::Model::Common
  include Ktistec::Model::Polymorphic

  @@table_name = "tasks"

  # The table includes a column named "failures" that subclasses can
  # define and use to serialize information about task failures.

  # The table includes a column named "state" that subclasses can
  # define and use to serialize information about task state.

  @@table_columns = ["failures", "state"]

  # Priority sets the order in which tasks are spawned by the task
  # worker.  See `TaskWorker#work`.

  class_property priority = 0

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
      cleanup = <<-SQL
         DELETE FROM tasks
          WHERE running = 0
            AND complete = 1
            AND backtrace IS NULL
            AND created_at < ?
      SQL
      exec(cleanup, now - 2.hours)
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

  # NOTE: This method is redefined when running tests. Invoking
  # `schedule` immediately invokes `perform`.

  def schedule(next_attempt_at = nil)
    raise "Not runnable" unless runnable? || complete
    self.next_attempt_at = next_attempt_at if next_attempt_at
    self.complete = false
    TaskWorker.schedule(self)
  end

  def perform
    raise NotImplementedError.new("Task#perform must be implemented in each subclass")
  end

  def self.destroy_old_tasks
    delete = "DELETE FROM tasks WHERE (complete = 1 OR backtrace IS NOT NULL) AND created_at < date('now', '-1 month')"
    Task.exec(delete)
  end

  def self.clean_up_running_tasks
    update = "UPDATE tasks SET running = 0 WHERE running = 1"
    Task.exec(update)
  end

  # Minimum time delta threshold for applying randomization.
  #
  # Task scheduling deltas below this threshold will not be randomized
  # to maintain precision for short-interval tasks.
  #
  MIN_RANDOMIZATION_THRESHOLD = 5.minutes

  # Threshold for adaptive randomization calculation .
  #
  # Intervals shorter than this use `ADAPTIVE_RANDOMIZATION_PERCENTAGE_SHORT`.
  # Intervals longer than or equal to this use `ADAPTIVE_RANDOMIZATION_PERCENTAGE_LONG`.
  #
  ADAPTIVE_RANDOMIZATION_THRESHOLD = 6.hours

  # Adaptive randomization percentage for short intervals.
  #
  # This percentage represents the total randomization range (e.g., 0.05 = 5%
  # total range, meaning ±2.5%). Used when adaptive randomization is enabled
  # and the interval is shorter than `ADAPTIVE_RANDOMIZATION_THRESHOLD`.
  #
  ADAPTIVE_RANDOMIZATION_PERCENTAGE_SHORT = 0.05

  # Adaptive randomization percentage for long intervals.
  #
  # This percentage represents the total randomization range (e.g., 0.025 = 2.5%
  # total range, meaning ±1.25%). Used when adaptive randomization is enabled
  # and the interval is greater than or equal to `ADAPTIVE_RANDOMIZATION_THRESHOLD`.
  #
  ADAPTIVE_RANDOMIZATION_PERCENTAGE_LONG = 0.025

  # Returns a randomized next attempt time based on the given delta.
  #
  # Applies proportional randomization to prevent tasks from running in
  # lockstep after server restarts. The randomization amount is adaptive
  # unless explicitly provided.
  #
  # ## Parameters
  #
  # - `delta` - The base time delta for scheduling
  # - `randomization_percentage` - Optional percentage override. When `nil`,
  #   an adaptive percentage is calculated based on interval length.
  #
  # ## General Behavior
  #
  # - For deltas less than `MIN_RANDOMIZATION_THRESHOLD`, returns the exact
  #   time delta (no randomization).
  # - For deltas greater than or equal to the threshold, returns a time
  #   within a percentage range of the delta (e.g., 5% means 97.5% to 102.5%
  #   of the delta).
  #
  protected def randomized_next_attempt_at(delta : Time::Span, randomization_percentage : Float64? = nil) : Time
    if delta < MIN_RANDOMIZATION_THRESHOLD
      delta.from_now
    else
      percentage = randomization_percentage || (delta < ADAPTIVE_RANDOMIZATION_THRESHOLD ? ADAPTIVE_RANDOMIZATION_PERCENTAGE_SHORT : ADAPTIVE_RANDOMIZATION_PERCENTAGE_LONG)
      half_range = delta.total_seconds * percentage / 2.0
      random_variation = Random::DEFAULT.rand(-half_range..half_range)
      adjusted_delta = delta + random_variation.seconds
      adjusted_delta.from_now
    end
  end
end
