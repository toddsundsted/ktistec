h1 Community
section.ui.cards
  - accounts.map(&.actor).each do |actor|
    == render "src/views/partials/actor-small.html.slang"
h1 Activity
section.ui.feed
  - objects.each do |object|
    crystal:
      activity = object.activities.first?
      activity = object.activities.find do |activity|
        Relationship::Content::Outbox.find?(to_iri: activity.iri)
      end
      _actor = activity && activity.responds_to?(:actor) ? activity.actor : object.attributed_to
      _author = object.attributed_to
    == object_partial(env, object, activity: activity, actor: _actor, author: _author)
== paginate(env, objects)
