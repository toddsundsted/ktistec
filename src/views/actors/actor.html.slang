- if !actor.blocked?
  - content_for "head" do
    link rel="alternate" type="application/rss+xml" title="#{actor.display_name}: RSS Feed" href=Utils::Paths.actor_rss_feed_path(actor)
  - content_for "og_metadata" do
    - partial "partials/actor/og_metadata"
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
