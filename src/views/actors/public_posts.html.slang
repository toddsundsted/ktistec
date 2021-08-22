section.ui.feed
  - objects.each do |object|
    crystal:
      activity = object.activities.find do |activity|
        Relationship::Content::Outbox.find?(from_iri: actor.iri, to_iri: activity.iri)
      end
      _actor = activity && activity.responds_to?(:actor) ? activity.actor : object.attributed_to
      _author = object.attributed_to
    == object_partial(env, object, activity: activity, actor: _actor, author: _author)
== paginate(env, objects)
