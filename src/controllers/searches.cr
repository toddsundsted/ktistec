require "web_finger"

require "../framework/controller"
require "../framework/open"
require "../framework/signature"

class SearchesController
  include Ktistec::Controller

  get "/search" do |env|
    message = nil
    actor_or_object = nil

    if (query = env.params.query["query"]?)
      url = URI.parse(query)
      url =
        if url.scheme && url.host && url.path
          query
        else
          if query.starts_with?("@")
            query = query[1..]
          end
          WebFinger.query("acct:#{query}").link("self").href.not_nil!
        end
      actor_or_object =
        if url.starts_with?("#{host}/actors/")
          ActivityPub::Actor.find(url)
        elsif url.starts_with?("#{host}/objects/")
          ActivityPub::Object.find(url)
        else
          headers = Ktistec::Signature.sign(env.account.actor, url, method: :get)
          headers["Accept"] = Ktistec::Constants::ACCEPT_HEADER
          Ktistec::Open.open(url, headers) do |response|
            ActivityPub.from_json_ld(response.body, include_key: true)
          end
        end
    end

    case actor_or_object
    when ActivityPub::Actor
      actor = actor_or_object.save

      ok "searches/actor"
    when ActivityPub::Object
      actor_or_object.attributed_to?(env.account.actor, dereference: true)
      object = actor_or_object.save

      ok "searches/object"
    else
      ok "searches/form"
    end
  rescue ex : Errors
    message = ex.message

    bad_request "searches/form"
  end

  private alias Errors = Socket::Addrinfo::Error | JSON::ParseException |
                         HostMeta::Error | WebFinger::Error | Ktistec::Open::Error |
                         NilAssertionError
end
