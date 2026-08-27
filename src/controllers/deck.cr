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

  # Returns the feeds rendered as panes, in pane order.
  #
  def self.panes_for(actor : ActivityPub::Actor) : Array(Feed)
    Feed.where("owner_iri = ? AND draft = 0 ORDER BY id LIMIT ?", actor.iri, MAX_PANES)
  end

  get "/actors/:username/deck" do |env|
    unless (account = get_account_with_ownership(env))
      not_found
    end

    entries = panes_for(account.actor).map { |feed| {feed, feed.contents(limit: POSTS_PER_PANE)} }

    ok "deck/show", env: env, actor: account.actor, entries: entries
  end

  # Returns true if the client is navigating the pane's own frame.
  #
  private def self.pane_frame?(env, feed)
    env.request.headers["Turbo-Frame"]? == "feed-#{feed.id}-pane"
  end

  # Renders a pane's next page of posts, wrapped in a turbo-stream
  # that replaces the sentinel which asked for it.
  #
  private def self.render_sentinel_replacement(env, actor, feed, contents)
    body = render "src/views/deck/contents.html.slang"
    %(<turbo-stream action="replace" target="feed-#{feed.id}-sentinel"><template>#{body}</template></turbo-stream>)
  end

  # Returns a pane's posts.
  #
  get "/actors/:username/deck/panes/:id" do |env|
    unless (feed = get_pane_feed_with_ownership(env))
      not_found
    end

    if pane_frame?(env, feed)
      ok "deck/pane", env: env, actor: feed.owner, feed: feed, contents: feed.contents(limit: POSTS_PER_PANE)
    else
      env.response.content_type = "text/vnd.turbo-stream.html"

      max_id = cursor_param(env.params.query, "max").try(&.to_i64?)

      render_sentinel_replacement(env, feed.owner, feed, feed.contents(max_id: max_id, limit: POSTS_PER_PANE))
    end
  end
end
