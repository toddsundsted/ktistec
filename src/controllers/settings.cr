require "../framework/controller"
require "../views/view_helper"
require "../models/activity_pub/activity/follow"
require "../models/task/terminate"

class SettingsController
  include Ktistec::Controller
  include Ktistec::ViewHelper

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

    actor.assign(params(env, actor))

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

    settings.assign(params(env, actor))

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

  private def self.params(env, actor)
    params = (env.params.body.presence || env.params.json.presence).not_nil!
    {
      "name" => params["name"]?.try(&.to_s),
      "summary" => params["summary"]?.try(&.to_s),
      "image" => params["image"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" } || actor.image,
      "icon" => params["icon"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" } || actor.icon,
      "footer" => params["footer"]?.try(&.to_s.presence),
      "site" => params["site"]?.try(&.to_s.presence)
    }
  end
end
