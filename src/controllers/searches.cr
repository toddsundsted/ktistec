require "../framework/controller"
require "../framework/util"
require "../ktistec/constants"
require "../utils/network"
require "../utils/web_finger"

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
        url = Ktistec::WebFinger.resolve(query)
        actor_or_object =
          if url.starts_with?("#{host}/actors/")
            ActivityPub::Actor.find(url)
          elsif url.starts_with?("#{host}/objects/")
            ActivityPub::Object.find(url)
          else
            headers = HTTP::Headers{"Accept" => Ktistec::Constants::ACCEPT_HEADER}
            fetch_activity_pub(env.account.actor, url, headers)
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

  # Fetches and parses an ActivityPub resource from `url`.
  #
  # When the response is an HTML page (e.g. a human-facing permalink
  # that doesn't content-negotiate to JSON-LD), follow `link` to the
  # ActivityPub representation and fetch that instead.
  #
  private def self.fetch_activity_pub(key_pair, url, headers, *, follow_alternate = true)
    response = Ktistec::Network.get(key_pair, url, headers)
    return ActivityPub.from_json_ld(response.body, include_key: true) unless html_response?(response)
    if follow_alternate && (href = discover_activity_pub_link(response.body, url))
      fetch_activity_pub(key_pair, href, headers, follow_alternate: false)
    else
      raise Ktistec::Network::Error.new("Could not find an ActivityPub resource at #{url}")
    end
  end

  private def self.html_response?(response) : Bool
    response.headers["Content-Type"]?.try(&.downcase.includes?("html")) || false
  end

  private def self.discover_activity_pub_link(body, base) : String?
    doc = XML.parse_html(body)
    if (node = doc.xpath_nodes(%q(//link[@rel='alternate' and @type='application/activity+json']/@href)).first?)
      href = URI.parse(base).resolve(node.text).to_s
      href if Ktistec::Util.safe_iri?(href) && href != base
    end
  rescue XML::Error | URI::Error
    nil
  end

  private alias Errors = Socket::Addrinfo::Error | JSON::ParseException |
                         Ktistec::HostMeta::Error | Ktistec::WebFinger::Error | Ktistec::Network::Error |
                         NilAssertionError
end
