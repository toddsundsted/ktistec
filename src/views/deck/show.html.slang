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
  turbo-stream-source src=stream_path("actor", "deck")
  - entries.each_with_index do |(feed, contents), index|
    section.deck-pane data-controller="deck-reorder" data-deck-reorder-overflow-value=overflow.to_s
      header
        h2 = feed.name
        nav.ui.small.secondary.menu.pane-controls
          / `position` is only used when javascript is unavailable.
          / otherwise the position sent is computed when the form is
          / submitted and this value is ignored.
          = form_tag(nil, actor_deck_pane_position_path(actor, feed), class: "pane-move", data: {"action": "submit->deck-reorder#move", "deck-reorder-direction": "left"}) do
            input type="hidden" name="position" value=(index - 1)
            button.link.item class=(index == 0 ? "disabled" : "") type="submit" disabled=(index == 0)
              i.angle.left.icon
              | Move Left
          = form_tag(nil, actor_deck_pane_position_path(actor, feed), class: "pane-move", data: {"action": "submit->deck-reorder#move", "deck-reorder-direction": "right"}) do
            input type="hidden" name="position" value=(index + 1)
            button.link.item class=(index == entries.size - 1 && !overflow ? "disabled" : "") type="submit" disabled=(index == entries.size - 1 && !overflow)
              | Move Right
              i.angle.right.icon
          .right.menu
            a.item href=actor_feeds_path(actor) Manage Feeds
            a.item href=edit_actor_feed_path(actor, feed) Edit Feed
      - partial "deck/pane"
