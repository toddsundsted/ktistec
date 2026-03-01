require "../task"
require "./mixins/singleton"
require "../session"

class Task
  # Monitors server health.
  #
  class Monitor < Task
    include Singleton

    Log = ::Log.for(self)

    # ensures that the monitor task spawns after all other tasks. this
    # prevents the case where the task worker reserves multiple tasks,
    # but due to nondeterministic ordering this task runs before the
    # other tasks spawn (which results in warnings, below).

    class_getter priority = -10

    def running_tasks_without_fibers
      Task.where(running: true).select do |task|
        task.is_a?(Task::ConcurrentTask) && task.fiber.nil?
      end
    end

    def perform
      Log.trace { "monitoring" }
      running_tasks_without_fibers.each do |task|
        Log.warn { %Q|#{task.class} id=#{task.id} is "running" but no running fiber exists| }
      end
      Session.clean_up_stale_sessions
    ensure
      # run on a random schedule
      delay = RANDOM.rand(15..300)
      self.next_attempt_at = delay.seconds.from_now
    end

    private RANDOM = Random.new
  end
end
