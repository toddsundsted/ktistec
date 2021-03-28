section.ui.feed
  - thread.each do |object|
    == object_partial(env, object, for_thread: thread)
