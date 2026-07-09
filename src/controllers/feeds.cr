require "../framework/controller"
require "../models/feed"

class FeedsController
  include Ktistec::Controller

  # Authorizes feed access.
  #
  # Feeds are personal and may surface non-public content, so access
  # is owner-only. Returns the feed if the authenticated user owns
  # the account and the account's actor owns the feed, `nil`
  # otherwise.
  #
  private def self.get_feed_with_ownership(env)
    if (account = Account.find?(username: env.params.url["username"]))
      if env.account? == account
        if (id = env.params.url["id"].to_i64?) && (feed = Feed.find?(id))
          if feed.owner_iri == account.actor.iri
            feed
          end
        end
      end
    end
  end

  get "/actors/:username/feeds/:id" do |env|
    unless (feed = get_feed_with_ownership(env))
      not_found
    end

    contents = feed.contents(**cursor_pagination_params(env))

    ok "feeds/show", env: env, feed: feed, contents: contents
  end
end
