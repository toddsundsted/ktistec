- if env.account?
  h1= actor.username
  .ui.secondary.four.item.menu
    a.item href=actor_relationships_path(actor, "drafts") Drafts
    a.item href=actor_relationships_path(actor, "notifications") Notifications
    a.item href=actor_relationships_path(actor, "followers") Followers
    a.item href=actor_relationships_path(actor, "following") Following
  - object = ActivityPub::Object.new(iri: "#{host}/objeccts/#{id}", attributed_to: actor)
  == render "src/views/partials/editor.html.slang"
- else
  == render "src/views/partials/actor-medium.html.slang"
crystal:
  activities = env.account? ?
    actor.both_mailboxes(*pagination_params(env)) :
    actor.my_timeline(*pagination_params(env))
h2 Recent
section.ui.feed
  - activities.each do |activity|
    - if activity.is_a?(ActivityPub::Activity::Create) || activity.is_a?(ActivityPub::Activity::Announce)
      == render "src/views/partials/activity/create.html.slang"
== paginate(activities, env)
