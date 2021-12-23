require "../framework/controller"
require "../framework/constants"

class WellKnownController
  include Ktistec::Controller

  skip_auth ["/.well-known/*"]

  get "/.well-known/webfinger" do |env|
    domain = (host =~ /\/\/([^\/]+)$/) && $1

    server_error unless $1
    bad_request unless resource = env.params.query["resource"]?
    bad_request unless resource =~ /^(acct:)?([^@]+)@(#{domain})$/

    Account.find(username: $2).actor

    message = {
      subject: resource,
      aliases: [
        "#{host}/@#{$2}",
        "#{host}/actors/#{$2}"
      ],
      links: [{
                rel: "self",
                href: "#{host}/actors/#{$2}",
                type: Ktistec::Constants::CONTENT_TYPE_HEADER
              }, {
                rel: "http://webfinger.net/rel/profile-page",
                href: "#{host}/@#{$2}",
                type: "text/html"
              }, {
                rel: "http://ostatus.org/schema/1.0/subscribe",
                template: "#{host}/actors/#{$2}/authorize-follow?uri={uri}"
              }]
    }
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
        }
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
