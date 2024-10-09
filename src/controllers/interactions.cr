require "../framework/controller"
require "../utils/network"

class InteractionsController
  include Ktistec::Controller

  skip_auth ["/objects/:id/remote-:action"], GET
  skip_auth ["/actors/:username/remote-follow"], GET
  skip_auth ["/remote-interaction"], POST

  get "/objects/:id/remote-:action" do |env|
    id = env.params.url["id"]
    action = env.params.url["action"]

    object_iri = "#{host}/objects/#{id}"

    unless (message = generate_message(action, object_iri))
      not_found
    end

    ok "interactions/index", env: env, message: message, error: nil, target: object_iri, action: action, domain: nil
  end

  get "/actors/:username/remote-follow" do |env|
    username = env.params.url["username"]

    actor_iri = "#{host}/actors/#{username}"

    unless (message = generate_message("follow", actor_iri))
      not_found
    end

    ok "interactions/index", env: env, message: message, error: nil, target: actor_iri, action: "follow", domain: nil
  end

  post "/remote-interaction" do |env|
    if (params = (env.params.body.presence || env.params.json.presence))
      if (param = params["domain"]?) && param.is_a?(String)
        domain = param.lstrip('@').presence
      end
      if (param = params["target"]?) && param.is_a?(String)
        target = param.presence
      end
      if (param = params["action"]?) && param.is_a?(String)
        action = param.presence
      end
    end

    unless target && action && (message = generate_message(action, target))
      bad_request
    end

    if domain
      begin
        location = WebFinger.query(domain).link("http://ostatus.org/schema/1.0/subscribe").template
        location = location.not_nil!.gsub("{uri}", target)
        if accepts?("text/html")
          redirect location
        else
          {location: location}.to_json
        end
      rescue ex : HostMeta::Error | WebFinger::Error | NilAssertionError | KeyError
        bad_request "interactions/index", env: env, message: message, error: ex.message, target: target, action: action, domain: domain
      end
    else
      unprocessable_entity "interactions/index", env: env, message: message, error: "the domain must not be blank", target: target, action: action, domain: nil
    end
  end

  get "/authorize-interaction" do |env|
    unless (uri = env.params.query["uri"]?)
      bad_request("Missing URI")
    end
    uri = Ktistec::Network.resolve(uri)
    actor_or_object =
      if uri.starts_with?("#{host}/actors/")
        ActivityPub::Actor.find(uri)
      elsif uri.starts_with?("#{host}/objects/")
        ActivityPub::Object.find(uri)
      else
        headers = HTTP::Headers{"Accept" => Ktistec::Constants::ACCEPT_HEADER}
        Ktistec::Open.open?(env.account.actor, uri, headers) do |response|
          ActivityPub.from_json_ld(response.body, include_key: true)
        end
      end
    case actor_or_object
    when ActivityPub::Actor
      actor = actor_or_object.save
      actor.up!
      ok "actors/remote", env: env, actor: actor
    when ActivityPub::Object
      actor_or_object.attributed_to?(env.account.actor, dereference: true)
      object = actor_or_object.save
      ok "objects/object", env: env, object: object, recursive: false
    else
      bad_request("Can't Dereference URI")
    end
  end

  private def self.generate_message(action, target)
    case action
    when "reply"
      if (object = ActivityPub::Object.find?(target))
        "reply to #{object.attributed_to.name}'s post"
      end
    when "like", "share"
      if (object = ActivityPub::Object.find?(target))
        "#{action} #{object.attributed_to.name}'s post"
      end
    when "follow"
      if (actor = ActivityPub::Actor.find?(target))
        "follow #{actor.name}"
      end
    end
  end
end
