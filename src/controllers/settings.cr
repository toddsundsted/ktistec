require "../framework/controller"
require "../models/activity_pub/activity/follow"

class SettingsController
  include Ktistec::Controller

  get "/settings" do |env|
    actor = env.account.actor

    ok "settings/settings"
  end

  post "/settings" do |env|
    actor = env.account.actor

    actor.assign(**params(env, actor)).save

    redirect back_path
  end

  private def self.params(env, actor)
    params = (env.params.body.presence || env.params.json.presence).not_nil!
    {
      name: params["name"]?.try(&.to_s),
      summary: params["summary"]?.try(&.to_s),
      image: params["image"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" } || actor.image,
      icon: params["icon"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" } || actor.icon
    }
  end
end
