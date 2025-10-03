require "../framework/controller"

class AdminController
  include Ktistec::Controller

  get "/admin" do |env|
    ok "admin/index", env: env
  end
end
