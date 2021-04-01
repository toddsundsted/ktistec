section.ui.feed
  - drafts.each do |object|
    == object_partial(env, object)
== paginate(drafts, env)
