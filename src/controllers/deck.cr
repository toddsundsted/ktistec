require "../framework/controller"
require "../models/feed"

# The `DeckController` renders a user's published feeds side by side,
# as independently scrolling panes.
#
class DeckController
  include Ktistec::Controller

  MAX_PANES = 12

  POSTS_PER_PANE = 20

  # Authorizes access to a user's deck.
  #
  # Returns the account if the authenticated user owns the account,
  # `nil` otherwise.
  #
  private def self.get_account_with_ownership(env)
    if (account = Account.find?(username: env.params.url["username"]))
      account if env.account? == account
    end
  end

  # Authorizes access to a single pane's feed.
  #
  # Returns the feed if the authenticated user owns it and it is
  # published, `nil` otherwise.
  #
  private def self.get_pane_feed_with_ownership(env)
    if (account = get_account_with_ownership(env))
      if (id = env.params.url["id"].to_i64?) && (feed = Feed.find?(id))
        feed if feed.owner == account.actor && !feed.draft
      end
    end
  end

  get "/actors/:username/deck" do |env|
    unless (account = get_account_with_ownership(env))
      not_found
    end

    feeds = Feed.where("owner_iri = ? AND draft = 0 ORDER BY id LIMIT ?", account.actor.iri, MAX_PANES)

    entries = feeds.map { |feed| {feed, feed.contents(limit: POSTS_PER_PANE)} }

    ok "deck/show", env: env, actor: account.actor, entries: entries
  end

  # Returns a pane's next page of posts.
  #
  get "/actors/:username/deck/panes/:id" do |env|
    unless (feed = get_pane_feed_with_ownership(env))
      not_found
    end

    max_id = cursor_param(env.params.query, "max").try(&.to_i64?)

    actor = feed.owner                                              # ameba:disable Lint/UselessAssign
    contents = feed.contents(max_id: max_id, limit: POSTS_PER_PANE) # ameba:disable Lint/UselessAssign

    env.response.content_type = "text/vnd.turbo-stream.html"

    body = render "src/views/deck/contents.html.slang"

    %(<turbo-stream action="replace" target="feed-#{feed.id}-sentinel"><template>#{body}</template></turbo-stream>)
  end
end
