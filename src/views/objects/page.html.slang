section.ui.feed data-controller="icon-load-error"
  - objects.each do |object|
    == object_partial(env, object, with_detail: true, in_reply: true)
