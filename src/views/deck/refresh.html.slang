div id="feed-#{feed.id}-refresh" class="pane-refresh"
  a.ui.small.info.icon.message href=actor_deck_pane_path(actor, feed) data-turbo-prefetch="false" data-turbo-frame="feed-#{feed.id}-pane"
    i.sync.icon
    .content
      .header There are new posts!
      p Reload this feed
