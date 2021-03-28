section.ui.feed
  - thread.each do |object|
    article.threaded.event id=anchor(object) class=depth(object)
      == object_partial(env, object)
