- query = env.request.query.try { |query| "?#{query}" } || ""
turbo-stream-source src="/stream/actor/homepage#{query}"
section.ui.feed data-controller="icon-load-error"
  #refresh-posts-message
  - timeline.each do |entry|
    crystal:
      object = entry.object
      activity = object.activities(inclusion: [ActivityPub::Activity::Announce, ActivityPub::Activity::Create]).find do |activity|
        Relationship::Content::Outbox.find?(owner: actor, activity: activity) ||
          Relationship::Content::Inbox.find?(owner: actor, activity: activity)
      end
      _actor = activity ? activity.actor : object.attributed_to
      _author = object.attributed_to
    == object_partial(env, object, activity: activity, actor: _actor, author: _author)
== paginate(env, timeline)
