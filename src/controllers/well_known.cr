require "../framework/controller"
require "../framework/constants"

class WellKnownController
  include Ktistec::Controller

  skip_auth ["/.well-known/*"], GET, OPTIONS

  get "/.well-known/webfinger" do |env|
    domain = URI.parse(host).host

    bad_request unless resource = env.params.query["resource"]?
    bad_request unless resource =~ %r<
      ^https://(#{domain})/(actors/|@)(?<username>.+)$|
      ^(acct:)?(?<username>[^@]+)@(#{domain})$|
      ^https://(#{domain})$|
      ^(#{domain})$
    >mx

    if (username = $~["username"]?)
      Account.find(username: username).actor # raise error if not found
      message = {
        subject: "acct:#{username}@#{domain}",
        aliases: [
          "#{host}/actors/#{username}"
        ],
        links: [{
                  rel: "self",
                  href: "#{host}/actors/#{username}",
                  type: Ktistec::Constants::CONTENT_TYPE_HEADER
                }, {
                  rel: "http://webfinger.net/rel/profile-page",
                  href: "#{host}/@#{username}",
                  type: "text/html"
                }, {
                  rel: "http://ostatus.org/schema/1.0/subscribe",
                  template: "#{host}/authorize-interaction?uri={uri}"
                }]
      }
    else
      message = {
        subject: domain,
        aliases: [
          host
        ],
        links: [{
                  rel: "http://ostatus.org/schema/1.0/subscribe",
                  template: "#{host}/authorize-interaction?uri={uri}"
                }]
      }
    end
    env.response.content_type = "application/jrd+json"
    env.response.headers.add("Access-Control-Allow-Origin", "*")
    message.to_json
  rescue Ktistec::Model::NotFound
    not_found
  end

  get "/.well-known/nodeinfo" do |env|
    message = {
      links: [{
                rel: "http://nodeinfo.diaspora.software/ns/schema/2.1",
                href: "#{host}/.well-known/nodeinfo/2.1"
              }]
    }
    env.response.content_type = "application/jrd+json"
    env.response.headers.add("Access-Control-Allow-Origin", "*")
    message.to_json
  end

  record CachedCount, ident : Int64, count : Int64

  class_property cached_count = CachedCount.new(0, 0)

  def self.local_posts
    if (ident = ActivityPub::Object.latest_public_post) != self.cached_count.ident
      count = ActivityPub::Object.public_posts_count
      self.cached_count = CachedCount.new(ident, count)
    end
    self.cached_count.count
  end

  get "/.well-known/nodeinfo/2.1" do |env|
    message = {
      version: "2.1",
      software: {
        name: "ktistec",
        version: Ktistec::VERSION,
        repository: "https://github.com/toddsundsted/ktistec",
        homepage: "https://ktistec.com/"
      },
      protocols: [
        "activitypub"
      ],
      services: {
        inbound: [] of String,
        outbound: [] of String
      },
      openRegistrations: false,
      usage: {
        users: {
          total: Account.count
        },
        localPosts: local_posts
      },
      metadata: {
        siteName: Ktistec.site
      }
    }
    env.response.content_type = "application/jrd+json"
    env.response.headers.add("Access-Control-Allow-Origin", "*")
    message.to_json
  end

  private macro set_cors_headers
    env.response.headers.add("Access-Control-Allow-Origin", "*")
    env.response.headers.add("Access-Control-Allow-Methods", "OPTIONS, GET")
    env.response.headers.add("Access-Control-Allow-Headers", "MCP-Protocol-Version")
    env.response.content_type = "application/json"
  end

  options "/.well-known/oauth-protected-resource/mcp" do |env|
    set_cors_headers
    no_content
  end

  get "/.well-known/oauth-protected-resource/mcp" do |env|
    message = {
      resource: host,
      authorization_servers: [host],
      scopes_supported: ["mcp"],
      bearer_methods_supported: ["header"],
    }
    set_cors_headers
    message.to_json
  end

  options "/.well-known/oauth-authorization-server" do |env|
    set_cors_headers
    no_content
  end

  get "/.well-known/oauth-authorization-server" do |env|
    message = {
      issuer: host,
      registration_endpoint: "#{host}/oauth/register",
      authorization_endpoint: "#{host}/oauth/authorize",
      token_endpoint: "#{host}/oauth/token",
      scopes_supported: ["mcp"],
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code"],
      token_endpoint_auth_methods_supported: ["client_secret_basic"],
      code_challenge_methods_supported: ["S256"],
    }
    set_cors_headers
    message.to_json
  end
end
