section.ui.feed
  - drafts.each do |object|
    article.event id=anchor(object)
      == object_partial(env, object)
== paginate(drafts, env)
