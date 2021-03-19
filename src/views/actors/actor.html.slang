- if env.account?
  h1= actor.username
  .ui.secondary.five.item.menu
    a.item href=actor_relationships_path(actor, "inbox") Inbox
    a.item href=actor_relationships_path(actor, "outbox") Outbox
    a.item href=actor_relationships_path(actor, "drafts") Drafts
    a.item href=actor_relationships_path(actor, "followers") Followers
    a.item href=actor_relationships_path(actor, "following") Following
  form.ui.form data-controller="has-content multi-action" data-action="submit->multi-action#squelch" method="POST"
    input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
    input type="hidden" name="type" value="Publish"
    input type="hidden" name="public" value="true"
    .field
      input#input-trix-editor type="hidden" name="content"
      trix-editor data-controller="trix" data-action="trix-attachment-add@window->trix#add trix-attachment-remove@window->trix#remove trix-change@window->trix#change input->has-content#change" data-has-content-target="input" input="input-trix-editor"
    .ui.buttons
      input.ui.disabled.primary.button data-has-content-target="button" data-action="click->multi-action#submit" type="submit" value="Post Status" action=outbox_path(actor)
      input.ui.disabled.button data-has-content-target="button" data-action="click->multi-action#submit" type="submit" value="Save Draft" action=objects_path
- else
  == render "src/views/partials/actor-medium.html.slang"
crystal:
  activities = env.account? ?
    actor.both_mailboxes(*pagination_params(env)) :
    actor.my_timeline(*pagination_params(env))
h2 Recent
section.ui.feed
  - activities.each do |activity|
    article.event.activity
      - if activity.is_a?(ActivityPub::Activity::Create) || activity.is_a?(ActivityPub::Activity::Announce)
        == render "src/views/partials/activities/create.html.slang"
== paginate(activities, env)
