require "web_finger"

require "../framework/controller"
require "../framework/open"
require "../framework/signature"

class SearchesController
  include Ktistec::Controller

  get "/search" do |env|
    actor_or_object = nil

    if (query = env.params.query["query"]?)
      url = URI.parse(query)
      url =
        if url.scheme && url.host && url.path
          query
        else
          WebFinger.query("acct:#{query}").link("self").href.not_nil!
        end
      actor_or_object =
        if url.starts_with?("#{host}/actors/")
          ActivityPub::Actor.find(url)
        elsif url.starts_with?("#{host}/objects/")
          ActivityPub::Object.find(url)
        else
          headers = Ktistec::Signature.sign(env.account.actor, url, method: :get).merge!(HTTP::Headers{"Accept" => "application/activity+json"})
          Ktistec::Open.open(url, headers) do |response|
            ActivityPub.from_json_ld(response.body, include_key: true)
          end
        end
    end

    case actor_or_object
    when ActivityPub::Actor
      actor_or_object.save

      accepts?("text/html") ?
        actor_html(env, actor_or_object, query) :
        actor_json(env, actor_or_object, query)
    when ActivityPub::Object
      actor_or_object.attributed_to?(env.account.actor, dereference: true)
      actor_or_object.save

      accepts?("text/html") ?
        object_html(env, actor_or_object, query) :
        object_json(env, actor_or_object, query)
    else
      accepts?("text/html") ?
        form_html(env, query) :
        form_json(env, query)
    end
  rescue ex : Errors
    env.response.status_code = 400
    accepts?("text/html") ?
      form_html(env, query, ex.message) :
      form_json(env, query, ex.message)
  end

  private alias Errors = Socket::Addrinfo::Error | JSON::ParseException |
                         HostMeta::Error | WebFinger::Error | Ktistec::Open::Error |
                         NilAssertionError

  private def self.actor_html(env, actor, query = nil, message = nil)
    env.response.content_type = "text/html"
    render "src/views/searches/actor.html.slang", "src/views/layouts/default.html.ecr"
  end

  private def self.actor_json(env, actor, query = nil, message = nil)
    env.response.content_type = "application/json"
    JSON.build do |json|
      json.object do
        json.field "msg", message if message
        json.field "query", query || ""
        json.field "actor", actor
      end
    end
  end

  private def self.object_html(env, object, query = nil, message = nil)
    env.response.content_type = "text/html"
    render "src/views/searches/object.html.slang", "src/views/layouts/default.html.ecr"
  end

  private def self.object_json(env, object, query = nil, message = nil)
    env.response.content_type = "application/json"
    JSON.build do |json|
      json.object do
        json.field "msg", message if message
        json.field "query", query || ""
        json.field "object", object
      end
    end
  end

  private def self.form_html(env, query = nil, message = nil)
    env.response.content_type = "text/html"
    render "src/views/searches/form.html.slang", "src/views/layouts/default.html.ecr"
  end

  private def self.form_json(env, query = nil, message = nil)
    env.response.content_type = "application/json"
    JSON.build do |json|
      json.object do
        json.field "msg", message if message
        json.field "query", query || ""
      end
    end
  end
end
