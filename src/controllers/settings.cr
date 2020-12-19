require "../framework/controller"
require "../models/activity_pub/activity/follow"

class SettingsController
  include Ktistec::Controller

  get "/settings" do |env|
    actor = env.account.actor

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/settings/settings.html.slang", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/settings/settings.json.ecr"
    end
  end

  post "/settings" do |env|
    actor = env.account.actor

    actor.assign(**params(env, actor)).save

    env.redirect back_path
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
