- if env.account?.try(&.actor) == actor
  crystal:
    filters = env.params.query.fetch_all("filters")
    count = actor.notifications(since: env.account.last_notifications_checked_at)
    tooltip = false
    if count > 0
      notifications = actor.notifications(size: count)
      groups =
        notifications.group_by do |notification|
          case notification
          in Relationship::Content::Notification::Follow
            "follow"
          in Relationship::Content::Notification::Reply
            "reply"
          in Relationship::Content::Notification::Mention
            "mention"
          in Relationship::Content::Notification::Announce, Relationship::Content::Notification::Like, Relationship::Content::Notification::Dislike
            "social"
          in Relationship::Content::Notification::Follow::Hashtag, Relationship::Content::Notification::Follow::Mention, Relationship::Content::Notification::Follow::Thread
            "content"
          in Relationship::Content::Notification
            "other"
          end
        end
      type_order = ["follow", "reply", "mention", "social", "content", "other"]
      tooltip = groups.to_a.sort_by { |type, _| type_order.index(type) || 99 }.map { |type, items| "#{type} #{items.size}" }.join(" | ")
    end
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
    .menu-items data-turbo-prefetch="false"
      a.item href=actor_relationships_path(actor, "posts") Posts
      a.item href=actor_relationships_path(actor, "drafts") Drafts
      a.item.notifications href=actor_relationships_path(actor, "notifications") title=tooltip Notifications
        - if count > 0
          span.ui.mini.transitional.horizontal.circular.red.label= count
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
  == _view_src_views_partials_actor_panel_html_slang(env, actor)
  - objects = actor.public_posts_with_pins(**pagination_params(env))
  == render "src/views/actors/public_posts.html.slang"
- else
  == _view_src_views_partials_actor_panel_html_slang(env, actor)
