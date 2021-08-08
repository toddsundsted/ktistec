h1 Community
section.ui.cards
  - accounts.map(&.actor).each do |actor|
    == render "src/views/partials/actor-small.html.slang"
h1 Activity
section.ui.feed
  - objects.each do |object|
    crystal:
      activity = object.activities.first?
      actor = activity && activity.responds_to?(:actor) ? activity.actor : object.attributed_to
      author = object.attributed_to
    == object_partial(env, object, actor: actor, author: author)
== paginate(objects, env)
