require "../models/task"

class TaskWorker
  @@channel = Channel(Task).new

  def self.start
    destroy_old_tasks
    clean_up_running_tasks

    self.new.tap do |worker|
      loop do
        unless worker.work
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

  def work(now = Time.utc)
    tasks = Task.scheduled(now)
    ids = tasks.map(&.id.to_s).join(",")
    update = "UPDATE tasks SET running = 1 WHERE id IN (#{ids})"
    Ktistec.database.exec(update)
    tasks.each do |task|
      if task.is_a?(Task::ConcurrentTask)
        spawn { perform(task) }
      else
        perform(task)
      end
    end
    !tasks.empty?
  end

  private def perform(task)
    next_attempt_at = task.next_attempt_at
    task.perform
  rescue ex
    message = ex.message ? "#{ex.class}: #{ex.message}" : ex.class.to_s
    task.backtrace = [message] + ex.backtrace
  ensure
    task.running = false
    task.complete = true unless (task.next_attempt_at != next_attempt_at) || task.backtrace
    task.last_attempt_at = Time.utc
    task.save(skip_validation: true, skip_associated: true)
  end

  def self.destroy_old_tasks
    delete = "DELETE FROM tasks WHERE (complete = 1 OR backtrace IS NOT NULL) AND created_at < date('now', '-1 month')"
    Ktistec.database.exec(delete)
  end

  def self.clean_up_running_tasks
    update = "UPDATE tasks SET running = 0 WHERE running = 1"
    Ktistec.database.exec(update)
  end
end
