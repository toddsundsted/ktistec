section.ui.feed data-controller="icon-load-error"
  - objects.each do |object|
    - partial object_partial(env, object, with_detail: true, as_context: true)
