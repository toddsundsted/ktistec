- contents.each do |object|
  - partial object_partial(env, object, scope: "feed-#{feed.id}")
- if contents.has_next? && (_cursor = contents.cursor_end)
  turbo-frame id="feed-#{feed.id}-sentinel" class="sentinel" loading="lazy" src=actor_deck_pane_path(actor, feed, _cursor)
    a href=actor_feed_path(actor, feed) data-turbo-frame="_top" More posts
