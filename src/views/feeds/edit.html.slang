- content_for "title" do
  | Edit Feed
h1 Edit Feed
- partial "feeds/form"
.ui.basic.tiny.delete-feed.modal
  .header
    i.trash.icon
    | Delete Feed
  .content
    p
      | Delete the feed <strong>#{feed.name}</strong>? The feed and everything it has collected are removed. The posts themselves stay in your inbox and timeline—only this feed goes away. This can't be undone.
  .actions
    .ui.basic.cancel.inverted.button
      i.remove.icon
      | Cancel
    .ui.red.ok.inverted.button
      i.trash.icon
      | Delete Feed
= form_button(actor_feed_path(actor, feed), method: "DELETE", button_class: "ui dangerous button", button_data: {"modal" => "delete-feed", "controller" => "modal-action", "action" => "click->modal-action#show"}) do
  | Delete Feed
