require "../framework/**"
require "../models/**"
require "../controllers/**"
require "../handlers/**"
require "../workers/**"

Ktistec::Server.run do
  Log.setup_from_env
  spawn { TaskWorker.start }
  Task::UpdateMetrics.schedule_unless_exists
  Session.clean_up_stale_sessions
end
