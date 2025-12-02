require "../framework/controller"
require "../framework/constants"
require "../framework/open"

class ProxyController
  include Ktistec::Controller

  post "/proxy" do |env|
    unless (id = get_id(env))
      bad_request "Missing 'id'"
    end
    headers = HTTP::Headers{"Accept" => Ktistec::Constants::ACCEPT_HEADER}
    Ktistec::Open.open(env.account.actor, id, headers) do |response|
      env.response.content_type = response.content_type || "application/ld+json"
      response.body
    end
  end

  private def self.get_id(env)
    if (id = env.params.body["id"]? || env.params.json["id"]?)
      id.as(String).presence
    end
  end
end
