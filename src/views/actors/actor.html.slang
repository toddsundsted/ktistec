- if env.account?.try(&.actor) == actor
  h1= actor.username
  .ui.secondary.four.item.menu
    a.item href=actor_relationships_path(actor, "drafts") Drafts
    .item
      a href=actor_relationships_path(actor, "notifications") Notifications
      - if (count = actor.notifications(since: env.account.last_notifications_checked_at)) > 0
        .ui.hidden.transitional.mini.horizontal.circular.red.label= count
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
  - objects = actor.public_posts(*pagination_params(env))
  == render "src/views/actors/public_posts.html.slang"
