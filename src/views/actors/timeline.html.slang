section.ui.feed
  - objects.each do |object|
    crystal:
      activity = object.activities.find do |activity|
        Relationship::Content::Outbox.find?(owner: actor, activity: activity) ||
          Relationship::Content::Inbox.find?(owner: actor, activity: activity)
      end
      _actor = activity && activity.responds_to?(:actor) ? activity.actor : object.attributed_to
      _author = object.attributed_to
    == object_partial(env, object, activity: activity, actor: _actor, author: _author)
== paginate(env, objects)
