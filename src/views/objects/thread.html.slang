section.ui.feed
  - if env.account? && (iri = thread.first.in_reply_to_iri.presence)
    == render "#{__DIR__}/partials/fetch.html.slang"
  - thread.each do |object|
    == object_partial(env, object, for_thread: thread)
