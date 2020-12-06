class TaskWorker
  def work(now = Time.utc)
    tasks = Task.scheduled(now)
    # TODO: fix possible race condition here
    ids = tasks.map(&.id.to_s).join(",")
    update = "UPDATE tasks SET running = 1 WHERE id IN (#{ids})"
    Ktistec.database.exec(update)
    tasks.each do |task|
      begin
        next_attempt_at = task.next_attempt_at
        task.perform
      rescue ex
        message = ex.message ? "#{ex.class}: #{ex.message}" : ex.class.to_s
        task.backtrace = [message] + ex.backtrace
      ensure
        task.running = false
        task.complete = true unless (task.next_attempt_at != next_attempt_at) || task.backtrace
        task.last_attempt_at = Time.utc
        task.save(skip_autosave: true)
      end
    end
    !tasks.empty?
  end

  def self.clean_up_running_tasks
    update = "UPDATE tasks SET running = 0 WHERE running = 1"
    Ktistec.database.exec(update)
  end
end
