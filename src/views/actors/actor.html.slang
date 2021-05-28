- if env.account?.try(&.actor) == actor
  h1= actor.username
  .ui.secondary.four.item.menu
    a.item href=actor_relationships_path(actor, "drafts") Drafts
    a.item href=actor_relationships_path(actor, "notifications") Notifications
    a.item href=actor_relationships_path(actor, "followers") Followers
    a.item href=actor_relationships_path(actor, "following") Following
  - object = ActivityPub::Object.new(iri: "#{host}/objects/new", attributed_to: actor)
  == render "src/views/partials/editor.html.slang"
  h2 Recent
  - objects = actor.timeline(*pagination_params(env))
  == render "src/views/actors/timeline.html.slang"
- else
  == render "src/views/partials/actor-medium.html.slang"
  h2 Recent
  - activities = actor.my_timeline(*pagination_params(env))
  section.ui.feed
    - activities.each do |activity|
      - if activity.is_a?(ActivityPub::Activity::Create) || activity.is_a?(ActivityPub::Activity::Announce)
        == render "src/views/partials/activity/create.html.slang"
  == paginate(activities, env)
