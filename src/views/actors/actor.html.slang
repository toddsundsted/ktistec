- if !actor.blocked?
  - content_for "head" do
    link rel="alternate" type="application/rss+xml" title="#{actor.display_name}: RSS Feed" href=Utils::Paths.actor_rss_feed_path(actor)
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
  - partial actor_panel_partial(env, actor)
  section.ui.feed data-controller="icon-load-error"
    - (pinned + objects.to_a).each do |object|
      crystal:
        activity = object.activities.find do |activity|
          Relationship::Content::Outbox.find?(owner: actor, activity: activity)
        end
        _actor = activity ? activity.actor : object.attributed_to
        _author = object.attributed_to
      - partial object_partial(env, object, activity: activity, actor: _actor, author: _author, for_actor: actor)
  - partial paginate(env, objects)
- else
  - partial actor_panel_partial(env, actor)
