require "web_finger"

require "../framework/controller"
require "../models/activity_pub/activity/follow"

class RemoteFollowsController
  include Ktistec::Controller

  skip_auth ["/actors/:username/remote-follow"], GET, POST

  get "/actors/:username/remote-follow" do |env|
    username = env.params.url["username"]

    unless (actor = Account.find?(username: username).try(&.actor))
      not_found
    end

    error = nil
    account = ""

    ok "remote_follows/index"
  end

  post "/actors/:username/remote-follow" do |env|
    username = env.params.url["username"]

    unless (actor = Account.find?(username: username).try(&.actor))
      not_found
    end

    account = account(env)

    if !account.presence
      error = "the address must not be blank"

      unprocessable_entity "remote_follows/index"
    else
      begin
        location = lookup(account).gsub("{uri}", URI.encode_path(actor.iri))
        if accepts?("text/html")
          redirect location
        else
          env.response.content_type = "application/json"
          {location: location}.to_json
        end
      rescue ex : HostMeta::Error | WebFinger::Error | NilAssertionError | KeyError
        error = ex.message

        bad_request "remote_follows/index"
      end
    end
  end

  get "/actors/:username/authorize-follow" do |env|
    username = env.params.url["username"]

    unless (account = Account.find?(username: username))
      not_found
    end
    unless account == env.account
      forbidden
    end

    unless (uri = env.params.query["uri"]?)
      bad_request("Missing URI")
    end
    unless (actor = ActivityPub::Actor.dereference?(env.account.actor, uri).try(&.save))
      bad_request("Can't Dereference URI")
    end

    ok "actors/remote"
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
