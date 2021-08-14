section.ui.feed
  - collection.each do |object|
    == object_partial(env, object)
== paginate(env, collection)
