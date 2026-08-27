turbo-frame id="feed-#{feed.id}-pane"
  div id="feed-#{feed.id}-refresh" class="pane-refresh"
  - if contents.empty?
    p Nothing here yet.
  - else
    .ui.feed data-controller="icon-load-error"
      - partial "deck/contents"
