crystal:
  classes = [
    activity_type_class(activity),
    object_type_class(object),
    object_states(object),
  ].compact.flatten.join(" ")
turbo-frame.detailed.event id=anchor(object) class=classes
  == _view_src_views_partials_object_label_html_slang(env, author, actor)
  == _view_src_views_partials_object_content_html_slang(env, object, author, actor, with_detail, in_reply, for_thread, for_actor)
