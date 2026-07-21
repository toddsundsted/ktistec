require "../framework/controller"
require "../models/feed"
require "../rules/feeds"
require "../services/feed/judging"
require "../services/feed/window"
require "../services/feed/backend/criteria/form"

# The `FeedsController` manages the lifecycle of feeds and their
# associated content windows (previews).
#
#                            ┌───────┐──┐ preview:
#    ┌─── preview: ────────▶ │ draft │◀─┘ update feed;
#    │    create feed;       └───────┘    recompute window
#    │    recompute window     │   ▲
#    │                         │   │
#    │               publish:  │   │ preview [1]:
#    │          adopt window;  │   │ create a draft feed;
#  [NEW]       register feed;  │   │ recompute window;
#    │         unregister and  │   │ keep the original
#    │       destroy original  │   │
#    │                         │   │
#    │                         ▼   │
#    │                   ┌───────────┐──┐ publish [2]:
#    └─ publish: ──────▶ │ published │◀─┘ create new feed;
#       create feed;     └───────────┘    register new feed;
#       register feed                     unregister and
#                                         destroy old feed
#
# [1] A published feed is never demoted to a draft feed. Instead, a
#   new draft feed is created (recording the original in `copy_of`)
#   and the original published feed is left unchanged until the draft
#   feed is published.
# [2] A published feed is never mutated. Instead, a new published feed
#   is created and the original published feed is unregistered and
#   destroyed.
#
# Deleting a feed in any state unregisters and destroys it.
#
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
  # Returns the feed if the authenticated user owns the feed, `nil`
  # otherwise.
  #
  private def self.get_feed_with_ownership(env)
    if (account = get_account_with_ownership(env))
      if (id = env.params.url["id"].to_i64?) && (feed = Feed.find?(id))
        feed if feed.owner == account.actor
      end
    end
  end

  get "/actors/:username/feeds" do |env|
    unless (account = get_account_with_ownership(env))
      not_found
    end

    feeds =
      if env.params.query["include"]? == "drafts"
        Feed.where("owner_iri = ? ORDER BY created_at DESC", account.actor.iri)
      else
        Feed.where("owner_iri = ? AND draft = 0 ORDER BY created_at DESC", account.actor.iri)
      end

    # feeds with no posts sort first: an empty feed is most likely one
    # just published with criteria still being tuned, and it is the
    # thing the owner needs to find again.
    entries = feeds.map do |feed|
      {feed, Feed::Backend::Criteria::Form.summarize(feed.params), feed.stats}
    end.sort_by! { |feed, _, stats| {stats.newest ? 0 : 1, stats.newest || Time::UNIX_EPOCH, feed.created_at} }.reverse!

    ok "feeds/index", env: env, actor: account.actor, entries: entries
  end

  get "/actors/:username/feeds/new" do |env|
    unless (account = get_account_with_ownership(env))
      not_found
    end

    feed = Feed.new(owner: account.actor, backend: "criteria", name: "")

    criteria = form_criteria(env, feed)

    ok "feeds/new", env: env, feed: feed, criteria: criteria, contents: nil
  end

  post "/actors/:username/feeds" do |env|
    unless (account = get_account_with_ownership(env))
      not_found
    end

    cap_request_body env, MAX_REQUEST_BYTES

    params = feed_params(env)

    if previewing?(env)
      feed = Feed.new(**params.merge({owner: account.actor, backend: "criteria", draft: true}))
      if feed.valid?
        feed.save
        Feed::Window.new(feed).recompute
        redirect edit_actor_feed_path(account.actor, feed)
      else
        criteria = form_criteria(env, feed)
        unprocessable_entity "feeds/new", env: env, feed: feed, criteria: criteria, contents: nil
      end
    else
      feed = Feed.new(**params.merge({owner: account.actor, backend: "criteria", draft: false}))
      if feed.valid?
        feed.save
        Rules::Feeds.register(feed)
        if accepts?("application/ld+json", "application/activity+json", "application/json")
          created actor_feed_path(account.actor, feed), "feeds/show", env: env, feed: feed, contents: feed.contents(**cursor_pagination_params(env))
        else
          redirect actor_feeds_path(account.actor)
        end
      else
        criteria = form_criteria(env, feed)
        unprocessable_entity "feeds/new", env: env, feed: feed, criteria: criteria, contents: nil
      end
    end
  end

  get "/actors/:username/feeds/:id" do |env|
    unless (feed = get_feed_with_ownership(env))
      not_found
    end

    if feed.draft
      redirect edit_actor_feed_path(feed.owner, feed)
    end

    contents = feed.contents(**cursor_pagination_params(env))

    ok "feeds/show", env: env, feed: feed, contents: contents
  end

  get "/actors/:username/feeds/:id/edit" do |env|
    unless (feed = get_feed_with_ownership(env))
      not_found
    end

    contents = feed.draft ? Feed::Window.new(feed).contents : feed.contents(limit: Feed::Window::MATCH_CAP)

    criteria = form_criteria(env, feed)

    ok "feeds/edit", env: env, feed: feed, criteria: criteria, contents: contents
  end

  post "/actors/:username/feeds/:id" do |env|
    unless (feed = get_feed_with_ownership(env))
      not_found
    end

    cap_request_body env, MAX_REQUEST_BYTES

    params = feed_params(env)

    if feed.draft
      original = feed.original?

      unless feed.assign(**params).valid?
        criteria = form_criteria(env, feed)
        unprocessable_entity "feeds/edit", env: env, feed: feed, criteria: criteria, contents: nil
      end

      if previewing?(env)
        feed.save
        Feed::Window.new(feed).recompute
        redirect edit_actor_feed_path(feed.owner, feed)
      else
        feed.publish
        Rules::Feeds.register(feed)
        if original && original.owner == feed.owner
          Feed::Judging.rejudge_contents(original, feed)
          unregister_and_destroy(original)
        end
        redirect actor_feeds_path(feed.owner)
      end
    else
      if previewing?(env)
        if feed.assign(**params).valid?
          discard_superseded_copies(feed)
          copy = Feed.new(**params.merge({owner: feed.owner, backend: "criteria", draft: true, copy_of: feed.id})).save
          Feed::Window.new(copy).recompute
          redirect edit_actor_feed_path(feed.owner, copy)
        else
          criteria = form_criteria(env, feed)
          unprocessable_entity "feeds/edit", env: env, feed: feed, criteria: criteria, contents: nil
        end
      else
        published = Feed.new(**params.merge({owner: feed.owner, backend: "criteria", draft: false}))
        if published.valid?
          published.save
          Rules::Feeds.register(published)
          Feed::Judging.rejudge_contents(feed, published)
          unregister_and_destroy(feed)
          redirect actor_feeds_path(feed.owner)
        else
          feed.assign(**params)
          criteria = form_criteria(env, feed)
          unprocessable_entity "feeds/edit", env: env, feed: feed, criteria: criteria, contents: nil
        end
      end
    end
  end

  delete "/actors/:username/feeds/:id" do |env|
    unless (feed = get_feed_with_ownership(env))
      not_found
    end

    unregister_and_destroy(feed)

    redirect actor_feeds_path(feed.owner)
  end

  # Discards any existing draft copies of a published feed.
  #
  private def self.discard_superseded_copies(feed)
    Feed.where("copy_of = ? AND draft = 1", feed.id).each(&.destroy)
  end

  # Removes a feed's runtime view before destroying the feed itself.
  #
  private def self.unregister_and_destroy(feed)
    Rules::Feeds.unregister(feed)
    feed.destroy
  end

  # Returns the criteria, as form text, for a feed.
  #
  # When validation fails, echoes back the submission verbatim.
  #
  private def self.form_criteria(env, feed)
    if feed.errors.presence
      params = normalize_params(env.params.body.presence || env.params.json)
      criteria_strings(params)
    else
      Feed::Backend::Criteria::Form.format(feed.params)
    end
  end

  # Whether the submission is a preview request instead of a publish
  # request.
  #
  private def self.previewing?(env)
    params = normalize_params(env.params.body.presence || env.params.json)
    params.has_key?("preview")
  end

  private def self.feed_params(env)
    params = normalize_params(env.params.body.presence || env.params.json)
    criteria = criteria_strings(params)
    {
      name:        params["name"]?.as?(String) || "",
      description: params["description"]?.as?(String),
      params:      Feed::Backend::Criteria::Form.parse(criteria[:any], criteria[:all], criteria[:none]),
    }
  end

  private def self.criteria_strings(params)
    {
      any:  params["any"]?.as?(String) || "",
      all:  params["all"]?.as?(String) || "",
      none: params["none"]?.as?(String) || "",
    }
  end
end
