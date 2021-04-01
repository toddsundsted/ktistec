require "../framework/controller"
require "../views/view_helper"
require "../models/activity_pub/activity/follow"
require "../models/task/terminate"

class SettingsController
  include Ktistec::Controller
  extend Ktistec::ViewHelper

  get "/settings" do |env|
    actor = env.account.actor

    ok "settings/settings"
  end

  post "/settings" do |env|
    actor = env.account.actor

    actor.assign(**params(env, actor)).save

    redirect back_path
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
      name: params["name"]?.try(&.to_s),
      summary: params["summary"]?.try(&.to_s),
      image: params["image"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" } || actor.image,
      icon: params["icon"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" } || actor.icon
    }
  end
end
