require "../rules/**"
require "../framework/**"
require "../models/**"
require "../controllers/**"
require "../handlers/**"
require "../workers/**"

Ktistec::Server.run do
  TaskWorker.start do
    Task.destroy_old_tasks
    Task.clean_up_running_tasks
    Task::Backup.schedule_unless_exists
    Task::Performance.schedule_unless_exists
    Task::UpdateMetrics.schedule_unless_exists
  end
  Session.clean_up_stale_sessions
  # track server starts
  Point.new(chart: "server-start", timestamp: Time.utc, value: 1).save
  # check the rules when the server starts
  ContentRules.domain
end
