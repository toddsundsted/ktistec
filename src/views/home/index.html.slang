section.ui.feed data-controller="icon-load-error"
  - # take advantage of existing feed styling for presentation #
  - if (description = Ktistec::DescriptionEnhancer.enhanced_description.presence)
    .ui.segments
      .ui.segment.event
        .content data-controller="image-gallery"
          .text
            == description
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
