require "../framework"
require "web_finger"

class LookupsController
  include Balloon::Controller

  get "/api/lookup" do |env|
    message = nil
    actor = nil

    if (account = env.params.query["account"]?)
      url = URI.parse(account)
      url =
        if url.scheme && url.host && url.path
          account
        else
          WebFinger.query("acct:#{account}").link("self").href
        end
      actor = ActivityPub::Actor.from_json_ld(get(url).body)
    end

    if accepts?("text/html")
      env.response.content_type = "text/html"
      render "src/views/lookups/actor.html.ecr"
    else
      env.response.content_type = "application/json"
      render "src/views/lookups/actor.json.ecr"
    end
  rescue ex : Error | Socket::Addrinfo::Error | HostMeta::Error | WebFinger::Error | JSON::ParseException
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

  private def self.get(url)
    if url
      headers = HTTP::Headers{"Accept" => "application/activity+json"}
      10.times do
        response = HTTP::Client.get(url, headers)
        case response.status_code
        when 200
          return response
        when 301, 302, 307, 308
          if url = response.headers["Location"]?
            next
          else
            break
          end
        else
          break
        end
      end
    end
    raise Error.new("failed to get #{url}")
  end

  private class Error < Exception
  end
end
