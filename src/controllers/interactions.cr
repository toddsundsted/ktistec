require "../framework/controller"
require "../utils/network"

class InteractionsController
  include Ktistec::Controller

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
