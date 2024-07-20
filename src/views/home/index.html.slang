- accounts.map(&.actor).each do |actor|
  == _view_src_views_partials_actor_panel_html_slang(env, actor)
section.ui.feed data-controller="icon-load-error"
  - objects.each do |object|
    crystal:
      activity = object.activities.first?
      activity = object.activities.find do |activity|
        Relationship::Content::Outbox.find?(activity: activity)
      end
      _actor = activity ? activity.actor : object.attributed_to
      _author = object.attributed_to
    == object_partial(env, object, activity: activity, actor: _actor, author: _author)
== paginate(env, objects)
