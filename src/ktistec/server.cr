require "../framework"
require "../framework/ext/**"
require "../framework/util"
require "../framework/controller"
require "../framework/database"
require "../framework/model"
require "../framework/json_ld"
require "../framework/jwt"
require "../framework/signature"
require "../framework/csrf"
require "../framework/auth"
require "../framework/rewrite"
require "../framework/method"
require "../workers/**"

Ktistec::Server.run do
  Log.setup_from_env
  spawn do
    Session.clean_up_stale_sessions
    TaskWorker.clean_up_running_tasks
    task_worker = TaskWorker.new
    loop do
      unless task_worker.work
        sleep 5.seconds
      end
    end
  end
end
