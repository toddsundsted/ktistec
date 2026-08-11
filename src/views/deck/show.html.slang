- content_for "title" do
  | Deck
- if entries.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.columns.icon
      | You don't have any feeds yet.
    .ui.text
      | The deck shows your published feeds side by side.
        Publish a feed and it appears here.
    .ui.hidden.divider
    a.ui.primary.button href=new_actor_feed_path(actor) New Feed
- else
  - entries.each do |feed, contents|
    section.deck-pane
      header
        h2 = feed.name
        a href=actor_feed_path(actor, feed) See all
      - if contents.empty?
        p Nothing here yet.
      - else
        .ui.feed data-controller="icon-load-error"
          - partial "deck/contents"
