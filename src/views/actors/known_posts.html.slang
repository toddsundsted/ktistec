section.ui.feed
  - objects.each do |object|
    == object_partial(env, object)
== paginate(env, objects)
