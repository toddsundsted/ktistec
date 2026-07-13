- if for_thread
  crystal:
    classes = [
      activity_type_class(activity),
      object_type_class(object),
      object_states(object, author, actor),
      depth(object),
    ].compact.flatten.join(" ")
  turbo-frame.threaded.event id=anchor(object) class=classes
    - partial "partials/object/label"
    - partial object_content_partial(env, object, author, actor, with_detail, as_context, show_quote, for_thread, for_actor)
- elsif with_detail
  crystal:
    classes = [
      activity_type_class(activity),
      object_type_class(object),
      object_states(object, author, actor),
    ].compact.flatten.join(" ")
  turbo-frame.detailed.event id=anchor(object) class=classes
    - partial "partials/object/label"
    - partial object_content_partial(env, object, author, actor, with_detail, as_context, show_quote, for_thread, for_actor)
- elsif themed
  crystal:
    viewing_actor = env.account?.try(&.actor)
    followed_actors = viewing_actor.try(&.followed_actors)
    followed_hashtags = viewing_actor.try(&.followed_hashtags)
    followed_mentions = viewing_actor.try(&.followed_mentions)
    classes = [
      highlight ? "highlighted" : nil,
      activity_type_class(activity),
      actor_type_class(actor),
      object_type_class(object),
      viewing_actor ? mention_states(object, viewing_actor) : nil,
      viewing_actor ? quote_states(object, viewing_actor) : nil,
      object_states(object, author, actor),
      actor_states(object, author, actor, followed_actors),
    ].compact.flatten.join(" ")
    attrs = object_data_attributes(object, author, actor, followed_hashtags, followed_mentions)
  turbo-frame.event id=anchor(object) class=classes *attrs
    - partial "partials/object/label"
    - partial object_content_partial(env, object, author, actor, with_detail, as_context, show_quote, for_thread, for_actor)
- else
  turbo-frame.event id=anchor(object)
    - partial "partials/object/label"
    - partial object_content_partial(env, object, author, actor, with_detail, as_context, show_quote, for_thread, for_actor)
