require "web_finger"

require "../framework/controller"
require "../models/activity_pub/activity/follow"

class RemoteFollowsController
  include Ktistec::Controller

  skip_auth ["/actors/:username/remote-follow"], GET, POST

  get "/actors/:username/remote-follow" do |env|
    username = env.params.url["username"]
    actor = Account.find(username: username).actor

    error = nil
    account = ""
    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/remote_follows/index.html.slang", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/json"
      render "src/views/remote_follows/index.json.ecr"
    end
  end

  post "/actors/:username/remote-follow" do |env|
    username = env.params.url["username"]
    actor = Account.find(username: username).actor

    account = account(env)
    if !account.presence
      error = "the address must not be blank"
      if accepts?("text/html")
        env.response.content_type = "text/html"
        render "src/views/remote_follows/index.html.slang", "src/views/layouts/default.html.ecr"
      else
        env.response.content_type = "application/json"
        render "src/views/remote_follows/index.json.ecr"
      end
    else
      begin
        location = lookup(account).gsub("{uri}", URI.encode(actor.iri))
        if accepts?("text/html")
          env.redirect location
        else
          env.response.content_type = "application/json"
          {location: location}.to_json
        end
      rescue ex : HostMeta::Error | WebFinger::Error | NilAssertionError | KeyError
        error = ex.message
        env.response.status_code = 400
        if accepts?("text/html")
          env.response.content_type = "text/html"
          render "src/views/remote_follows/index.html.slang", "src/views/layouts/default.html.ecr"
        else
          env.response.content_type = "application/json"
          render "src/views/remote_follows/index.json.ecr"
        end
      end
    end
  end

  get "/actors/:username/authorize-follow" do |env|
    unless (uri = env.params.query["uri"]?)
      bad_request("Missing URI")
    end
    unless (actor = ActivityPub::Actor.dereference?(uri).try(&.save))
      bad_request("Can't Dereference URI")
    end

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/actors/remote.html.slang", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/activity+json"
      render "src/views/actors/remote.json.ecr"
    end
  end

  private def self.lookup(account)
    WebFinger.query("acct:#{account}").link("http://ostatus.org/schema/1.0/subscribe").template.not_nil!
  end

  private def self.account(env)
    if (params = (env.params.body.presence || env.params.json.presence))
      params["account"]?.try(&.to_s)
    end
  end
end
