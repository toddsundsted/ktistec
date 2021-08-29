require "../framework/controller"
require "../models/task/terminate"

class SettingsController
  include Ktistec::Controller

  get "/settings" do |env|
    actor = env.account.actor

    settings = Ktistec.settings

    ok "settings/settings"
  end

  get "/settings/actor" do |env|
    redirect settings_path
  end

  get "/settings/service" do |env|
    redirect settings_path
  end

  post "/settings/actor" do |env|
    actor = env.account.actor

    settings = Ktistec.settings

    actor.assign(params(env))

    if actor.valid?
      actor.save

      redirect settings_path
    else
      ok "settings/settings"
    end
  end

  post "/settings/service" do |env|
    actor = env.account.actor

    settings = Ktistec.settings

    settings.assign(params(env))

    if settings.valid?
      settings.save

      redirect settings_path
    else
      ok "settings/settings"
    end
  end

  post "/settings/terminate" do |env|
    actor = env.account.actor

    Task::Terminate.new(source: actor, subject: actor).schedule

    env.account.destroy
    env.session.destroy

    redirect home_path
  end

  private def self.params(env)
    params = (env.params.body.presence || env.params.json.presence).not_nil!
    {
      "name" => params["name"]?.try(&.to_s),
      "summary" => params["summary"]?.try(&.to_s),
      # FilePond passes the _path_ as a "unique file id". Ktistec requires the full URI.
      "image" => params["image"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" },
      "icon" => params["icon"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" },
      "footer" => params["footer"]?.try(&.to_s.presence),
      "site" => params["site"]?.try(&.to_s.presence)
    }
  end
end
