require "web_finger"

require "../framework/controller"
require "../framework/open"
require "../models/activity_pub/activity/follow"

class SearchesController
  include Ktistec::Controller
  extend Ktistec::Open

  get "/search" do |env|
    message = nil
    actor = nil

    if (account = env.params.query["account"]?)
      url = URI.parse(account)
      url =
        if url.scheme && url.host && url.path
          account
        else
          WebFinger.query("acct:#{account}").link("self").href.not_nil!
        end
      open(url) do |response|
        json = Ktistec::JSON_LD.expand(response.body)
        if (iri = json.dig?("@id").try(&.as_s)) && (actor = ActivityPub::Actor.find?(iri))
          actor.from_json_ld(json)
        else
          actor = ActivityPub::Actor.from_json_ld(json)
        end
        actor.save
      end
    end

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/searches/actor.html.ecr", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/json"
      render "src/views/searches/actor.json.ecr"
    end
  rescue ex : Errors
    message = ex.message

    env.response.status_code = 400
    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/searches/actor.html.ecr", "src/views/layouts/default.html.ecr"
    else
      env.response.content_type = "application/json"
      render "src/views/searches/actor.json.ecr"
    end
  end

  private alias Errors = Socket::Addrinfo::Error | JSON::ParseException | NilAssertionError |
                         HostMeta::Error | WebFinger::Error | Ktistec::Open::Error
end
