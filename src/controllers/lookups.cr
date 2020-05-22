require "../framework"
require "web_finger"

class LookupsController
  include Balloon::Controller
  extend Balloon::Util

  get "/api/lookup" do |env|
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
        json = Balloon::JSON_LD.expand(response.body)
        if (aid = json.dig?("@id").try(&.as_s)) && (actor = ActivityPub::Actor.find?(aid: aid))
          actor.from_json_ld(json)
        else
          actor = ActivityPub::Actor.from_json_ld(json)
        end
        actor.save
      end
    end

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/lookups/actor.html.ecr"
    else
      env.response.content_type = "application/json"
      render "src/views/lookups/actor.json.ecr"
    end
  rescue ex : LookupErrors
    message = ex.message

    env.response.status_code = 400
    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/lookups/actor.html.ecr"
    else
      env.response.content_type = "application/json"
      render "src/views/lookups/actor.json.ecr"
    end
  end

  private alias LookupErrors = Socket::Addrinfo::Error | JSON::ParseException | NilAssertionError |
                               HostMeta::Error | WebFinger::Error |
                               Balloon::Util::OpenError
end
