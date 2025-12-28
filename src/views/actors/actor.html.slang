- if env.account?.try(&.actor) == actor
  crystal:
    filters = env.params.query.fetch_all("filters")
    count, color, tooltip = notification_count_and_color(actor, env.account.last_notifications_checked_at)
  .ui.stackable.secondary.menu
    input.menu-toggle-checkbox type="checkbox" id="menu-toggle"
    .mobile-menu-toggle
      label for="menu-toggle"
        i.bars.icon
        span.title Collections and Filters
        - if count > 0
          span.ui.mini.transitional.horizontal.circular.label class=color title=tooltip = count
        - else
          span.invisible.label
    .menu-items data-turbo-prefetch="false"
      a.item href=actor_relationships_path(actor, "posts") Posts
      a.item href=actor_relationships_path(actor, "drafts") Drafts
      a.item.notifications href=actor_relationships_path(actor, "notifications") Notifications
        - if count > 0
          span.ui.mini.transitional.horizontal.circular.label class=color title=tooltip = count
        - else
          span.invisible.label
      a.item href=actor_bookmarks_path(actor) Bookmarks
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
  - content_for "og_metadata" do
    crystal:
      og_title = actor.display_name.presence
      og_description_raw = actor.summary.presence || "#{actor.display_name} on #{Ktistec.settings.site}"
      og_description = Ktistec::Util.render_as_text_and_truncate(og_description_raw, 155)
      og_image = actor.icon.presence || actor.image.presence || Ktistec.settings.image.presence || "#{Ktistec.host}/images/logo.png"
    meta property="og:type" content="profile"
    meta property="og:title" content=og_title
    meta property="og:description" content=og_description
    meta property="og:url" content=actor.display_link
    meta property="og:image" content=og_image
    meta property="og:image:alt" content=actor.display_name
    meta property="profile:username" content=actor.username
    meta property="og:site_name" content=Ktistec.settings.site
    meta name="twitter:card" content="summary"
    meta name="twitter:title" content=og_title
    meta name="twitter:description" content=og_description
    meta name="twitter:image" content=og_image
  == _view_src_views_partials_actor_panel_html_slang(env, actor)
  - objects = actor.public_posts_with_pins(**pagination_params(env))
  == render "src/views/actors/public_posts.html.slang"
- else
  == _view_src_views_partials_actor_panel_html_slang(env, actor)
