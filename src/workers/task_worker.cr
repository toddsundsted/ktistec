require "../models/task"

class TaskWorker
  Log = ::Log.for(self)

  @@channel = Channel(Task).new

  @@performing_tasks = 0

  class_getter? running : Bool = false

  def self.start
    @@running = true
    yield
    self.new.tap do |worker|
      spawn do
        Fiber.current.name = "TaskWorker"
        loop do
          break unless @@running
          # try to keep the task worker alive in the face of critical,
          # but possibly transient, problems affecting the database --
          # in particular, insufficient disk space and locking. if
          # these things happen, individual tasks may be left in an
          # inconsistent state, but the task worker will continue to
          # process future tasks, which is less surprising and more
          # useful than the alternative.
          begin
            work_done = worker.work
          rescue ex : SQLite3::Exception
            Log.warn { "Exception while doing task work: #{ex.class}: #{ex.message}: #{ex.backtrace.first?}" }
            work_done = false
          end
          unless work_done
            select
            when @@channel.receive
              # process work
            when timeout(5.seconds)
              # process work
            end
          end
        end
      end
    end
  end

  def self.stop
    @@running = false
    60.times do
      break unless @@performing_tasks > 0
      Log.info { "Waiting for #{@@performing_tasks} tasks to complete..." }
      sleep 1.second
    end
  end

  def self.schedule(task)
    if Kemal.config.env != "test"
      select
      when @@channel.send task.save
        # no-op
      when timeout(0.seconds)
        # no-op
      end
    else
      task.save
    end
    task
  end

  protected def work(now = Time.utc)
    tasks = Task.scheduled(now, reserve: true)
    tasks.sort_by(&.class.priority.-).each do |task|
      if task.is_a?(Task::ConcurrentTask)
        spawn name: task.fiber_name do
          perform(task)
        end
      else
        perform(task)
      end
    end
    !tasks.empty?
  end

  private def perform(task)
    @@performing_tasks += 1
    next_attempt_at = task.next_attempt_at
    task.perform
  rescue ex
    message = ex.message ? "#{ex.class}: #{ex.message}" : ex.class.to_s
    task.backtrace = [message] + ex.backtrace
  ensure
    @@performing_tasks -= 1
    task.running = false
    task.complete = true unless (task.next_attempt_at != next_attempt_at) || task.backtrace
    task.last_attempt_at = Time.utc
    # destroying a running task is a lightweight signal that a task
    # should terminate itself, so don't save the task -- that will
    # resurrect it!
    if !task.gone?
      task.save(skip_validation: true, skip_associated: true)
    else
      Log.debug { "TaskWorker#perform task #{task.id} is gone" }
    end
  end
end
