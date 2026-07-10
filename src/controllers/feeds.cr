require "../framework/controller"
require "../models/feed"
require "../services/feed/backend/criteria/form"

class FeedsController
  include Ktistec::Controller

  # Authorizes access to a user's feeds.
  #
  # Returns the account if the authenticated user owns the account,
  # `nil` otherwise.
  #
  private def self.get_account_with_ownership(env)
    if (account = Account.find?(username: env.params.url["username"]))
      account if env.account? == account
    end
  end

  # Authorizes access to a single feed.
  #
  # Returns the feed if the authenticated user owns the account and
  # the account's actor owns the feed, `nil` otherwise.
  #
  private def self.get_feed_with_ownership(env)
    if (account = get_account_with_ownership(env))
      if (id = env.params.url["id"].to_i64?) && (feed = Feed.find?(id))
        feed if feed.owner_iri == account.actor.iri
      end
    end
  end

  get "/actors/:username/feeds" do |env|
    unless (account = get_account_with_ownership(env))
      not_found
    end

    feeds = Feed.where("owner_iri = ? ORDER BY created_at DESC", account.actor.iri)

    entries = feeds.map do |feed|
      {feed, Feed::Backend::Criteria::Form.summarize(feed.params), feed.stats}
    end

    ok "feeds/index", env: env, actor: account.actor, entries: entries
  end

  get "/actors/:username/feeds/:id" do |env|
    unless (feed = get_feed_with_ownership(env))
      not_found
    end

    contents = feed.contents(**cursor_pagination_params(env))

    ok "feeds/show", env: env, feed: feed, contents: contents
  end
end
