section.ui.feed data-controller="icon-load-error"
  - objects.each do |object|
    crystal:
      activity = object.activities.find do |activity|
        Relationship::Content::Outbox.find?(owner: actor, activity: activity)
      end
      _actor = activity ? activity.actor : object.attributed_to
      _author = object.attributed_to
    == object_partial(env, object, activity: activity, actor: _actor, author: _author)
== paginate(env, objects)
