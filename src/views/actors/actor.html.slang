- if env.account?.try(&.actor) == actor
  crystal:
    count = actor.notifications(since: env.account.last_notifications_checked_at)
    filters = env.params.query.fetch_all("filters")
  .ui.stackable.secondary.menu
    input.menu-toggle-checkbox type="checkbox" id="menu-toggle"
    .mobile-menu-toggle
      label for="menu-toggle"
        i.bars.icon
        span.title Collections and Filters
        - if count > 0
          span.ui.mini.transitional.horizontal.circular.red.label= count
        - else
          span.invisible.label
    .menu-items
      a.item href=actor_relationships_path(actor, "posts") Posts
      a.item href=actor_relationships_path(actor, "drafts") Drafts
      .item.notifications
        a href=actor_relationships_path(actor, "notifications") Notifications
        - if count > 0
          span.ui.mini.transitional.horizontal.circular.red.label= count
        - else
          span.invisible.label
      a.item href=actor_relationships_path(actor, "followers") Followers
      a.item href=actor_relationships_path(actor, "following") Following
      a.ui.right.dropdown.item data-controller="dropdown" data-action="click->dropdown#click"
        i.horizontal.sliders.icon
        .menu
          form data-controller="checkbox-submit" data-turbo-frame="main-timeline" data-turbo-action="replace"
            == params_to_inputs(env.params.query, exclude: ["filters"])
            input type="hidden" name="filters" value=""
            .item
              .ui.slider.checkbox
                input#timeline-no-shares type="checkbox" name="filters" value="no-shares" data-action="change->checkbox-submit#change" checked=filters.includes?("no-shares")
                label for="timeline-no-shares" Don't include shared posts
            .item
              .ui.slider.checkbox
                input#timeline-no-replies type="checkbox" name="filters" value="no-replies" data-action="change->checkbox-submit#change" checked=filters.includes?("no-replies")
                label for="timeline-no-replies" Don't include replies
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
  - content_for "head" do
    link rel="alternate" type="application/rss+xml" title="#{actor.display_name}: RSS Feed" href="/actors/#{actor.username}/feed.rss"
  == _view_src_views_partials_actor_panel_html_slang(env, actor)
  - objects = actor.public_posts(**pagination_params(env))
  == render "src/views/actors/public_posts.html.slang"
- else
  == _view_src_views_partials_actor_panel_html_slang(env, actor)
