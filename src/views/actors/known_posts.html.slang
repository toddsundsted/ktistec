section.ui.feed data-controller="icon-load-error"
  - objects.each do |object|
    == object_partial(env, object)
== paginate(env, objects)
