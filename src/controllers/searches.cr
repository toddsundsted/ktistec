require "../framework/controller"
require "../framework/open"
require "../framework/constants"
require "../utils/network"

class SearchesController
  include Ktistec::Controller

  get "/search" do |env|
    actor_or_object = nil
    actors = [] of ActivityPub::Actor
    message = nil

    if (query = env.params.query["query"]?)
      query = query.strip

      # is this a simple username search? (with optional leading "@")
      if query =~ /^@?([a-zA-Z0-9_]+)$/ && !query.includes?("://")
        prefix = query.lstrip('@')
        if prefix.size > 100
          message = "Query too long (maximum 100 characters)"
        else
          actors = ActivityPub::Actor.search_by_username(prefix)
          if actors.empty?
            message = %Q|No actors found matching "#{prefix}"|
          end
        end
      else
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
      if actors.empty?
        ok "searches/form", env: env, message: message, query: query
      else
        ok "searches/actors", env: env, actors: actors, message: message, query: query
      end
    end
  rescue ex : Errors
    bad_request "searches/form", env: env, message: ex.message, query: query
  end

  private alias Errors = Socket::Addrinfo::Error | JSON::ParseException |
                         HostMeta::Error | WebFinger::Error | Ktistec::Open::Error |
                         NilAssertionError
end
