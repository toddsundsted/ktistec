require "../framework/controller"

class DesignSystemController
  include Ktistec::Controller

  get "/.design-system" do |env|
    actor = env.account.actor

    ok "design_system/index", env: env, actor: actor
  end
end
