section.ui.feed data-controller="icon-load-error"
  - objects.each do |object|
    - object_partial(env, object, for_actor: actor, content_io: content_io)
- paginate(env, objects, content_io)
