require "../framework/controller"
require "../models/task/fetch/mixins/fetcher"
require "../models/task"

class TasksController
  include Ktistec::Controller

  get "/tasks" do |env|
    tasks = Task.where(complete: false)
    running_count = Task.running_count
    scheduled_soon_count = Task.scheduled_soon_count

    ok "tasks/index", env: env, tasks: tasks, running_count: running_count, scheduled_soon_count: scheduled_soon_count
  end
end
