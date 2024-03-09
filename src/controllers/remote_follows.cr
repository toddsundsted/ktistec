require "web_finger"

require "../framework/controller"
require "../models/activity_pub/activity/follow"
require "../utils/network"

class RemoteFollowsController
  include Ktistec::Controller

  skip_auth ["/actors/:username/remote-follow"], GET, POST

  get "/actors/:username/remote-follow" do |env|
    username = env.params.url["username"]

    unless (actor = Account.find?(username: username).try(&.actor))
      not_found
    end

    ok "remote_follows/index", env: env, error: nil, account: nil, actor: actor
  end

  post "/actors/:username/remote-follow" do |env|
    username = env.params.url["username"]

    unless (actor = Account.find?(username: username).try(&.actor))
      not_found
    end

    account = account(env)

    if !account.presence
      unprocessable_entity "remote_follows/index", env: env, error: "the address must not be blank", account: account, actor: actor
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
        bad_request "remote_follows/index", env: env, error: ex.message, account: account, actor: actor
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
    uri = Ktistec::Network.resolve(uri)
    unless (actor = ActivityPub::Actor.dereference?(env.account.actor, uri).try(&.save))
      bad_request("Can't Dereference URI")
    end

    ok "actors/remote", env: env, actor: actor
  end

  private def self.lookup(account)
    WebFinger.query("acct:#{account}").link("http://ostatus.org/schema/1.0/subscribe").template.not_nil!
  end

  private def self.account(env)
    if (params = (env.params.body.presence || env.params.json.presence))
      if (param = params["account"]?) && param.is_a?(String)
        param.lstrip('@')
      end
    end
  end
end
