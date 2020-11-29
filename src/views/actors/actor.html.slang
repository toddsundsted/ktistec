- if env.account?
  h1= actor.username
  .ui.secondary.four.item.menu
    a.item href=actor_relationships_path(actor, "inbox") Inbox
    a.item href=actor_relationships_path(actor, "outbox") Outbox
    a.item href=actor_relationships_path(actor, "followers") Followers
    a.item href=actor_relationships_path(actor, "following") Following
  form.ui.form method="POST" action=actor_relationships_path(actor, "outbox")
    input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
    input type="hidden" name="type" value="Create"
    input type="hidden" name="public" value="true"
    .field
      input#input-trix-editor type="hidden" name="content"
      trix-editor input="input-trix-editor"
    input.ui.button type="submit" value="Post Status"
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
