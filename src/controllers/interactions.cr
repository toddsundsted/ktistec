require "../framework/controller"
require "../utils/network"

class InteractionsController
  include Ktistec::Controller

  skip_auth ["/actors/:username/remote-follow"], GET, POST

  get "/actors/:username/remote-follow" do |env|
    username = env.params.url["username"]

    unless (actor = Account.find?(username: username).try(&.actor))
      not_found
    end

    ok "interactions/index", env: env, error: nil, domain: nil, actor: actor
  end

  post "/actors/:username/remote-follow" do |env|
    username = env.params.url["username"]

    unless (actor = Account.find?(username: username).try(&.actor))
      not_found
    end

    domain =
      if (params = (env.params.body.presence || env.params.json.presence))
        if (param = params["domain"]?) && param.is_a?(String)
          param.lstrip('@').presence
        end
      end

    if domain
      begin
        location = WebFinger.query("acct:#{domain}").link("http://ostatus.org/schema/1.0/subscribe").template
        location = location.not_nil!.gsub("{uri}", URI.encode_path(actor.iri))
        if accepts?("text/html")
          redirect location
        else
          {location: location}.to_json
        end
      rescue ex : HostMeta::Error | WebFinger::Error | NilAssertionError | KeyError
        bad_request "interactions/index", env: env, error: ex.message, domain: domain, actor: actor
      end
    else
      unprocessable_entity "interactions/index", env: env, error: "the domain must not be blank", domain: domain, actor: actor
    end
  end

  get "/authorize-interaction" do |env|
    unless (uri = env.params.query["uri"]?)
      bad_request("Missing URI")
    end
    uri = Ktistec::Network.resolve(uri)
    actor_or_object =
      begin
        headers = HTTP::Headers{"Accept" => Ktistec::Constants::ACCEPT_HEADER}
        Ktistec::Open.open?(env.account.actor, uri, headers) do |response|
          ActivityPub.from_json_ld(response.body, include_key: true)
        end
      end
    case actor_or_object
    when ActivityPub::Actor
      actor = actor_or_object.save
      ok "actors/remote", env: env, actor: actor
    when ActivityPub::Object
      actor_or_object.attributed_to?(env.account.actor, dereference: true)
      object = actor_or_object.save
      ok "objects/object", env: env, object: object, recursive: false
    else
      bad_request("Can't Dereference URI")
    end
  end
end
