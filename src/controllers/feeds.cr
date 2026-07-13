require "../framework/controller"
require "../models/feed"
require "../rules/feeds"
require "../services/feed/backend/criteria/form"

class FeedsController
  include Ktistec::Controller

  MAX_REQUEST_BYTES = 16_384

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

    feeds = Feed.where("owner_iri = ? AND draft = 0 ORDER BY created_at DESC", account.actor.iri)

    entries = feeds.map do |feed|
      {feed, Feed::Backend::Criteria::Form.summarize(feed.params), feed.stats}
    end

    ok "feeds/index", env: env, actor: account.actor, entries: entries
  end

  get "/actors/:username/feeds/new" do |env|
    unless (account = get_account_with_ownership(env))
      not_found
    end

    feed = Feed.new(owner: account.actor, backend: "criteria", name: "")

    buckets = form_buckets(env, feed)
    ok "feeds/new", env: env, actor: account.actor, feed: feed, any: buckets[:any], all: buckets[:all], none: buckets[:none]
  end

  post "/actors/:username/feeds" do |env|
    unless (account = get_account_with_ownership(env))
      not_found
    end

    cap_request_body env, MAX_REQUEST_BYTES

    feed = Feed.new(**feed_params(env).merge({owner: account.actor, backend: "criteria"}))

    if feed.valid?
      feed.save
      Rules::Feeds.register(feed)
      if accepts?("application/ld+json", "application/activity+json", "application/json")
        created actor_feed_path(account.actor, feed), "feeds/show", env: env, feed: feed, contents: feed.contents(**cursor_pagination_params(env))
      else
        redirect actor_feeds_path(account.actor)
      end
    else
      buckets = form_buckets(env, feed)
      unprocessable_entity "feeds/new", env: env, actor: account.actor, feed: feed, any: buckets[:any], all: buckets[:all], none: buckets[:none]
    end
  end

  get "/actors/:username/feeds/:id" do |env|
    unless (feed = get_feed_with_ownership(env))
      not_found
    end

    contents = feed.contents(**cursor_pagination_params(env))

    ok "feeds/show", env: env, feed: feed, contents: contents
  end

  get "/actors/:username/feeds/:id/edit" do |env|
    unless (feed = get_feed_with_ownership(env))
      not_found
    end

    buckets = form_buckets(env, feed)
    ok "feeds/edit", env: env, actor: feed.owner, feed: feed, any: buckets[:any], all: buckets[:all], none: buckets[:none]
  end

  post "/actors/:username/feeds/:id" do |env|
    unless (feed = get_feed_with_ownership(env))
      not_found
    end

    cap_request_body env, MAX_REQUEST_BYTES

    feed.assign(**feed_params(env))

    if feed.valid?
      feed.save
      if accepts?("application/ld+json", "application/activity+json", "application/json")
        ok "feeds/show", env: env, feed: feed, contents: feed.contents(**cursor_pagination_params(env))
      else
        redirect actor_feeds_path(feed.owner)
      end
    else
      buckets = form_buckets(env, feed)
      unprocessable_entity "feeds/edit", env: env, actor: feed.owner, feed: feed, any: buckets[:any], all: buckets[:all], none: buckets[:none]
    end
  end

  delete "/actors/:username/feeds/:id" do |env|
    unless (feed = get_feed_with_ownership(env))
      not_found
    end

    Rules::Feeds.unregister(feed)
    feed.destroy

    redirect actor_feeds_path(feed.owner)
  end

  private def self.form_buckets(env, feed)
    if feed.errors.presence
      params = normalize_params(env.params.body.presence || env.params.json)
      bucket_strings(params)
    else
      Feed::Backend::Criteria::Form.format(feed.params)
    end
  end

  private def self.feed_params(env)
    params = normalize_params(env.params.body.presence || env.params.json)
    buckets = bucket_strings(params)
    {
      name:        params["name"]?.as?(String) || "",
      description: params["description"]?.as?(String),
      params:      Feed::Backend::Criteria::Form.parse(buckets[:any], buckets[:all], buckets[:none]),
    }
  end

  private def self.bucket_strings(params)
    {
      any:  params["any"]?.as?(String) || "",
      all:  params["all"]?.as?(String) || "",
      none: params["none"]?.as?(String) || "",
    }
  end
end
