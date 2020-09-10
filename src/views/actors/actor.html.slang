- content_for "head" do
  link rel="stylesheet" type="text/css" href="/trix.css"
  script type="text/javascript" src="/trix.js"
h1= actor.username
.ui.secondary.four.item.menu
  a.item href=actor_relationships_path(actor, "inbox") Inbox
  a.item href=actor_relationships_path(actor, "outbox") Outbox
  a.item href=actor_relationships_path(actor, "followers") Followers
  a.item href=actor_relationships_path(actor, "following") Following
- if env.current_account?
  form.ui.form method="POST" action=actor_relationships_path(actor, "outbox")
    input type="hidden" name="type" value="Create"
    input type="hidden" name="public" value="true"
    .field
      input#input-trix-editor type="hidden" name="content"
      trix-editor input="input-trix-editor"
    input.ui.button type="submit" value="Post Status"
