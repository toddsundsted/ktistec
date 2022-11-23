require "../framework/**"
require "../models/**"
require "../controllers/**"
require "../handlers/**"
require "../workers/**"

Ktistec::Server.run do
  Log.setup_from_env
  spawn { TaskWorker.start }
  Task::Backup.schedule_unless_exists
  Task::Performance.schedule_unless_exists
  Task::UpdateMetrics.schedule_unless_exists
  Session.clean_up_stale_sessions
  # check the rules when the server starts
  ContentRules.domain
end
