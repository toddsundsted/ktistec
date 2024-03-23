require "../framework/controller"
require "../models/task/fetch/mixins/fetcher"
require "../models/task"

class TasksController
  include Ktistec::Controller

  get "/tasks" do |env|
    tasks = Task.where(complete: false)

    ok "tasks/index", env: env, tasks: tasks
  end
end
