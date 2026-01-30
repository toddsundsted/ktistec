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
    object_states(object),
    actor_states(object, author, actor, followed_actors),
  ].compact.flatten.join(" ")
  attrs = object_data_attributes(object, author, actor, followed_hashtags, followed_mentions)
turbo-frame.event id=anchor(object) class=classes *attrs
  == _view_src_views_partials_object_label_html_slang(env, author, actor)
  == _view_src_views_partials_object_content_html_slang(env, object, author, actor, with_detail, in_reply, for_thread, for_actor)
