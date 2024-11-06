require "../framework/controller"
require "../framework/open"
require "../framework/constants"
require "../utils/network"

class SearchesController
  include Ktistec::Controller

  get "/search" do |env|
    message = nil
    actor_or_object = nil

    if (query = env.params.query["query"]?)
      query = query.strip
      url = Ktistec::Network.resolve(query)
      actor_or_object =
        if url.starts_with?("#{host}/actors/")
          ActivityPub::Actor.find(url)
        elsif url.starts_with?("#{host}/objects/")
          ActivityPub::Object.find(url)
        else
          headers = HTTP::Headers{"Accept" => Ktistec::Constants::ACCEPT_HEADER}
          Ktistec::Open.open(env.account.actor, url, headers) do |response|
            ActivityPub.from_json_ld(response.body, include_key: true)
          end
        end
    end

    case actor_or_object
    when ActivityPub::Actor
      actor = actor_or_object.save

      actor_or_object.up!

      ok "searches/actor", env: env, actor: actor, message: message, query: query
    when ActivityPub::Object
      actor_or_object.attributed_to?(env.account.actor, dereference: true)
      object = actor_or_object.save

      ok "searches/object", env: env, object: object, message: message, query: query
    else
      ok "searches/form", env: env, message: message, query: query
    end
  rescue ex : Errors
    bad_request "searches/form", env: env, message: ex.message, query: query
  end

  private alias Errors = Socket::Addrinfo::Error | JSON::ParseException |
                         HostMeta::Error | WebFinger::Error | Ktistec::Open::Error |
                         NilAssertionError
end
