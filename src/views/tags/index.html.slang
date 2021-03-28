section.ui.feed
  - collection.each do |object|
    article.event id=anchor(object)
      == object_partial(env, object)
== paginate(collection, env)
