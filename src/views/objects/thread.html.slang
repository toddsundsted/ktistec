- if env.account?
  turbo-stream-source src=stream_path("objects", object.id, "thread")
- partial thread_page_thread_controls(env, thread, task, follow)
section.ui.feed data-controller="icon-load-error"
  #refresh-posts-message
  - thread.each do |object|
    - partial object_partial(env, object, for_thread: thread)
