require "../framework/controller"

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

    actor.assign(**params(env)).save

    env.redirect back_path
  end

  private def self.params(env)
    params = (env.params.body.presence || env.params.json.presence).not_nil!
    {
      name: params["name"]?.try(&.to_s),
      summary: params["summary"]?.try(&.to_s),
      image: params["image"]?.try { |path| "#{host}#{path}" },
      icon: params["icon"]?.try { |path| "#{host}#{path}" }
    }
  end
end
