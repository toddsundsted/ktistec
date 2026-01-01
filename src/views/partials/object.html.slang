- classes = [highlight ? "highlighted" : nil, activity_type_class(activity)].compact.join(" ")
turbo-frame.event id=anchor(object) class=classes
  == _view_src_views_partials_object_label_html_slang(env, author, actor)
  == _view_src_views_partials_object_content_html_slang(env, object, author, actor, with_detail, for_thread, for_actor)
