require "file_utils"
require "uuid"

require "../framework/controller"
require "../models/task/terminate"
require "../models/session"

class SettingsController
  include Ktistec::Controller

  get "/settings" do |env|
    account = env.account
    actor = account.actor

    settings = Ktistec.settings

    ok "settings/settings", env: env, account: account, actor: actor, settings: settings
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

    params = actor_params(env)

    account.assign(params)
    actor.assign(params)

    password_changed = account.changed?(:encrypted_password)

    if account.valid?
      account.save

      if password_changed
        Session.invalidate_for(account)
        redirect sessions_path
      else
        redirect settings_path
      end
    else
      unprocessable_entity "settings/settings", env: env, account: account, actor: actor, settings: settings
    end
  end

  post "/settings/service" do |env|
    account = env.account
    actor = account.actor

    settings = Ktistec.settings

    params = service_params(env)

    settings.assign(params)

    if settings.valid?
      settings.save

      redirect settings_path
    else
      unprocessable_entity "settings/settings", env: env, account: account, actor: actor, settings: settings
    end
  end

  post "/settings/terminate" do |env|
    actor = env.account.actor

    Task::Terminate.new(source: actor, subject: actor).schedule

    env.account.destroy
    env.session.destroy

    redirect home_path
  end

  # these methods have to handle two different sources of form data
  # (in addition to JSON data and urlencoded data): vanilla form
  # submission and FilePond-enhanced form submission.

  private def self.actor_params(env)
    params = (env.params.body.presence || env.params.json)

    # check for the presense of uploaded files. `rescue` because the
    # `files` invocation will fail if called on anything other than
    # form data.
    files = begin
              env.params.files.presence
            rescue HTTP::FormData::Error
            end
    if files
      ["image", "icon"].each do |name|
        if (upload = files[name]?) && (filename = upload.filename.presence) && upload.tempfile.size > 0
          filename = "#{env.account.actor.id}#{File.extname(filename)}"
          filepath = File.join("uploads", *Tuple(String, String, String).from(UUID.random.to_s.split("-")[0..2]))
          begin
            Dir.mkdir_p(File.join(Kemal.config.public_folder, filepath))
            upload.tempfile.chmod(0o644) # fix permissions
            FileUtils.mv(upload.tempfile.path, File.join(Kemal.config.public_folder, filepath, filename))
            params[name] = "/#{filepath}/#{filename}"
          rescue err : File::Error
            Log.warn { err.message }
          end
        end
      end
    end

    {
      "name" => params["name"]?.try(&.to_s),
      "summary" => params["summary"]?.try(&.to_s),
      "language" => params["language"]?.try(&.to_s),
      "timezone" => params["timezone"]?.try(&.to_s.presence),
      "password" => params["password"]?.try(&.to_s),
      "auto_approve_followers" => params["auto_approve_followers"]?.in?("1", true) || false,
      "auto_follow_back" => params["auto_follow_back"]?.in?("1", true) || false,
      "default_editor" => params["default_editor"]?.try(&.to_s),
      # FilePond passes the _path_ as a "unique file id". Ktistec requires the full URI.
      "image" => params["image"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" },
      "icon" => params["icon"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" },
      "attachments" => reduce_attachments(params)
    }.select do |k, v|
      v || k.in?("image", "icon", "auto_approve_followers", "auto_follow_back")
    end
  end

  private def self.service_params(env)
    params = (env.params.body.presence || env.params.json)

    # check for the presense of uploaded files. `rescue` because the
    # `files` invocation will fail if called on anything other than
    # form data.
    files = begin
              env.params.files.presence
            rescue HTTP::FormData::Error
            end
    if files
      ["image"].each do |name|
        if (upload = files[name]?) && (filename = upload.filename.presence) && upload.tempfile.size > 0
          filename = "#{env.account.actor.id}#{File.extname(filename)}"
          filepath = File.join("uploads", *Tuple(String, String, String).from(UUID.random.to_s.split("-")[0..2]))
          begin
            Dir.mkdir_p(File.join(Kemal.config.public_folder, filepath))
            upload.tempfile.chmod(0o644) # fix permissions
            FileUtils.mv(upload.tempfile.path, File.join(Kemal.config.public_folder, filepath, filename))
            params[name] = "/#{filepath}/#{filename}"
          rescue err : File::Error
            Log.warn { err.message }
          end
        end
      end
    end

    {
      # the host may not be changed via settings
      "site" => params["site"]?.try(&.to_s),
      # FilePond passes the _path_ as a "unique file id". Ktistec requires the full URI.
      "image" => params["image"]?.try(&.to_s.presence).try { |path| "#{host}#{path}" },
      "description" => params["description"]?.try(&.to_s),
      "footer" => params["footer"]?.try(&.to_s),
      "translator_service" => params["translator_service"]?.try(&.to_s),
      "translator_url" => params["translator_url"]?.try(&.to_s),
    }.select do |k, v|
      v || k.in?("image")
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
