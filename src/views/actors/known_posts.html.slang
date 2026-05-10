section.ui.feed data-controller="icon-load-error"
  - objects.each do |object|
    - partial object_partial(env, object, for_actor: actor)
- partial paginate(env, objects)
