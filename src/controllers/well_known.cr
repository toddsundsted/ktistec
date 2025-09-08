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

  record CachedPostsCount, id : Int64, count : Int64

  class_property cached_posts_count = CachedPostsCount.new(0, 0)

  def self.local_posts
    if (id = ActivityPub::Object.latest_public_post) != self.cached_posts_count.id
      count = ActivityPub::Object.public_posts_count
      self.cached_posts_count = CachedPostsCount.new(id, count)
    end
    self.cached_posts_count.count
  end

  record CachedMAUCount, timestamp : Int64, count : Int64

  class_property cached_mau_count = CachedMAUCount.new(0, 0)

  def self.monthly_active_users
    if (timestamp = Time.utc.at_beginning_of_day.to_unix) != self.cached_mau_count.timestamp
      count = Account.monthly_active_accounts_count
      self.cached_mau_count = CachedMAUCount.new(timestamp, count)
    end
    self.cached_mau_count.count
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
          total: Account.count,
          activeMonth: monthly_active_users,
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
end
