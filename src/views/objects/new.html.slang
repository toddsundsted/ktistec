h1 New Post
- if (in_reply_to = object.in_reply_to?)
  section.ui.feed data-controller="icon-load-error"
    - partial Ktistec::ViewHelper.object_partial(env, in_reply_to)
- partial "partials/editor"
br
