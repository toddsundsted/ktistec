section.ui.feed
  - objects.each do |object|
    crystal:
      activity = object.activities.first?
      actor = activity && activity.responds_to?(:actor) ? activity.actor : object.attributed_to
      author = object.attributed_to
    == object_partial(env, object, actor: actor, author: author)
== paginate(objects, env)
