require "../framework/controller"
require "../models/task/terminate"

class SettingsController
  include Ktistec::Controller

  get "/settings" do |env|
    account = env.account
    actor = account.actor

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
    account = env.account
    actor = account.actor

    settings = Ktistec.settings

    account.assign(params(env))
    actor.assign(params(env))

    if account.valid?
      account.save

      redirect settings_path
    else
      unprocessable_entity "settings/settings"
    end
  end

  post "/settings/service" do |env|
    account = env.account
    actor = account.actor

    settings = Ktistec.settings

    settings.assign(params(env))

    if settings.valid?
      settings.save

      redirect settings_path
    else
      unprocessable_entity "settings/settings"
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
      "timezone" => params["timezone"]?.try(&.to_s),
      "password" => params["password"]?.try(&.to_s),
      # FilePond passes the _path_ as a "unique file id". Ktistec requires the full URI.
      "image" => params["image"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" },
      "icon" => params["icon"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" },
      "footer" => params["footer"]?.try(&.to_s.presence),
      "site" => params["site"]?.try(&.to_s.presence),
      "attachments" => reduce_attachments(params)
    }.reject do |k, v|
      v.presence.nil? && k.in?("timezone", "password", "site")
    end
  end

  private def self.reduce_attachments(params)
    0.upto(ActivityPub::Actor::ATTACHMENT_LIMIT - 1).reduce(Array(ActivityPub::Actor::Attachment).new) do |memo, i|
      if params["attachment_#{i}_name"]?.try(&.to_s.presence) &&
          params["attachment_#{i}_value"]?.try(&.to_s.presence)
        memo << ActivityPub::Actor::Attachment.new(
          params["attachment_#{i}_name"].to_s,
          "PropertyValue",
          params["attachment_#{i}_value"].to_s
        )
      end
      memo
    end
  end
end
