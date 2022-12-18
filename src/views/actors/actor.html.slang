- if env.account?.try(&.actor) == actor
  .ui.compact.stackable.secondary.menu
    a.item href=actor_relationships_path(actor, "posts") Posts
    a.item href=actor_relationships_path(actor, "drafts") Drafts
    .item
      a.ui href=actor_relationships_path(actor, "notifications") Notifications
      - if (count = actor.notifications(since: env.account.last_notifications_checked_at)) > 0
        .ui.mini.hidden.transitional.horizontal.circular.red.label= count
    a.item href=actor_relationships_path(actor, "followers") Followers
    a.item href=actor_relationships_path(actor, "following") Following
  - object = ActivityPub::Object.new(iri: "#{host}/objects/new", attributed_to: actor)
  == render "src/views/partials/editor.html.slang"
  - objects = actor.timeline(**pagination_params(env))
  == render "src/views/actors/timeline.html.slang"
- elsif !actor.blocked?
  == render "src/views/partials/actor-panel.html.slang"
  - objects = actor.public_posts(**pagination_params(env))
  == render "src/views/actors/public_posts.html.slang"
- else
  == render "src/views/partials/actor-panel.html.slang"
