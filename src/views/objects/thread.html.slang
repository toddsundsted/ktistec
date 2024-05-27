== thread_page_thread_controls(env, thread, task, follow)
section.ui.feed data-controller="icon-load-error"
  - thread.each do |object|
    == object_partial(env, object, for_thread: thread)
