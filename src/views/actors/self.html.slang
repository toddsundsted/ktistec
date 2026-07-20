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
    a.item href=actor_feeds_path(actor) Feeds
    - env.account.pinned_collections.each do |label, path|
      a.item href=Utils::Paths.pinned_collection_path(path) = label
    a.ui.right.dropdown.item data-controller="dropdown" data-action="click->dropdown#click"
      i.horizontal.sliders.icon
      .menu
        form data-controller="checkbox-submit" data-turbo-frame="main-timeline" data-turbo-action="replace"
          = params_to_inputs(env.params.query, exclude: ["filters"])
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
- partial "partials/editor"
turbo-frame#main-timeline
  - partial "actors/timeline"
