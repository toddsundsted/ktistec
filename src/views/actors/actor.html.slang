- if env.account?.try(&.actor) == actor
  - filters = env.params.query.fetch_all("filters")
  .ui.stackable.secondary.menu
    a.item href=actor_relationships_path(actor, "posts") Posts
    a.item href=actor_relationships_path(actor, "drafts") Drafts
    .item
      a.ui href=actor_relationships_path(actor, "notifications") Notifications
      - if (count = actor.notifications(since: env.account.last_notifications_checked_at)) > 0
        .ui.mini.transitional.horizontal.circular.red.label= count
    a.item href=actor_relationships_path(actor, "followers") Followers
    a.item href=actor_relationships_path(actor, "following") Following
    a.ui.right.dropdown.item data-controller="dropdown" data-action="click->dropdown#click"
      i.horizontal.sliders.icon
      form.menu data-controller="checkbox-submit" data-turbo-frame="main-timeline" data-turbo-action="replace"
        == params_to_inputs(env.params.query, exclude: ["filters"])
        .item
          .ui.slider.checkbox
            input type="checkbox" name="filters" value="no-shares" data-action="change->checkbox-submit#change" checked=filters.includes?("no-shares")
            label Don't include shared posts
        .item
          .ui.slider.checkbox
            input type="checkbox" name="filters" value="no-replies" data-action="change->checkbox-submit#change" checked=filters.includes?("no-replies")
            label Don't include replies
  - object = ActivityPub::Object.new(iri: "#{host}/objects/new", attributed_to: actor)
  == render "src/views/partials/editor.html.slang"
  crystal:
    if filters.includes?("no-shares") && filters.includes?("no-replies")
      timeline = actor.timeline(**pagination_params(env), inclusion: [Relationship::Content::Timeline::Create], exclude_replies: true)
    elsif filters.includes?("no-shares")
      timeline = actor.timeline(**pagination_params(env), inclusion: [Relationship::Content::Timeline::Create])
    elsif filters.includes?("no-replies")
      timeline = actor.timeline(**pagination_params(env), exclude_replies: true)
    else
      timeline = actor.timeline(**pagination_params(env))
    end
  turbo-frame#main-timeline
    == render "src/views/actors/timeline.html.slang"
- elsif !actor.blocked?
  == render "src/views/partials/actor-panel.html.slang"
  - objects = actor.public_posts(**pagination_params(env))
  == render "src/views/actors/public_posts.html.slang"
- else
  == render "src/views/partials/actor-panel.html.slang"
