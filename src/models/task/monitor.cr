require "../task"
require "./mixins/singleton"

class Task
  # Monitors server health.
  #
  class Monitor < Task
    include Singleton

    Log = ::Log.for(self)

    def running_tasks_without_fibers
      Task.where(running: true).select do |task|
        task.is_a?(Task::ConcurrentTask) && task.fiber.nil?
      end
    end

    def perform
      # it's a kludge but briefly sleep while all of the other
      # reserved tasks spawn. this handles the case where the task
      # worker reserves multiple tasks, but due to nondeterministic
      # ordering this task runs before the other tasks spawn (which
      # results in warnings, below).
      sleep 1
      Log.trace { "monitoring" }
      running_tasks_without_fibers.each do |task|
        Log.warn { %Q|#{task.class} id=#{task.id} is "running" but no running fiber exists| }
      end
    ensure
      # run on a random schedule
      delay = Random::DEFAULT.rand(15..300)
      self.next_attempt_at = delay.seconds.from_now
    end
  end
end
