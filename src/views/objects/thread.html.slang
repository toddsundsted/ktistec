turbo-stream-source src="/stream/objects/#{object.id}/thread"
== thread_page_thread_controls(env, thread, task, follow)
section.ui.feed data-controller="icon-load-error"
  .refresh_posts_placeholder
  - thread.each do |object|
    == object_partial(env, object, for_thread: thread)
