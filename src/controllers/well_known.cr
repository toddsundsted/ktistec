require "../framework/controller"
require "../framework/constants"

class WellKnownController
  include Ktistec::Controller

  skip_auth ["/.well-known/*"], GET

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
        localPosts: ActivityPub::Object.public_posts_count
      },
      metadata: {
        siteName: Ktistec.site
      }
    }
    env.response.content_type = "application/jrd+json"
    env.response.headers.add("Access-Control-Allow-Origin", "*")
    message.to_json
  end
end
