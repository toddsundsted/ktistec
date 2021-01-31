- if env.account?
  h1= actor.username
  .ui.secondary.four.item.menu
    a.item href=actor_relationships_path(actor, "inbox") Inbox
    a.item href=actor_relationships_path(actor, "outbox") Outbox
    a.item href=actor_relationships_path(actor, "followers") Followers
    a.item href=actor_relationships_path(actor, "following") Following
  form.ui.form method="POST"
    input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
    input type="hidden" name="type" value="Publish"
    input type="hidden" name="public" value="true"
    .field
      input#input-trix-editor type="hidden" name="content"
      trix-editor input="input-trix-editor"
    .ui.buttons
      input.ui.disabled.primary.button type="submit" value="Post Status" action=outbox_path(actor)
      input.ui.disabled.button type="submit" value="Save Draft" action=objects_path
- else
  == render "src/views/partials/actor-medium.html.slang"
crystal:
  activities = env.account? ?
    actor.both_mailboxes(*pagination_params(env)) :
    actor.public_posts(*pagination_params(env))
h2 Recent
section.ui.feed
  - activities.each do |activity|
    article.event.activity
      - if activity.is_a?(ActivityPub::Activity::Create) || activity.is_a?(ActivityPub::Activity::Announce)
        == render "src/views/partials/activities/create.html.slang"
== paginate(activities, env)
