h1 Edit Post
- if (in_reply_to = object.in_reply_to?)
  section.ui.feed data-controller="icon-load-error"
    == Ktistec::ViewHelper.object_partial(env, in_reply_to, as_context: true)
- if (quote = object.quote?)
  section.ui.feed data-controller="icon-load-error"
    == Ktistec::ViewHelper.object_partial(env, quote, as_context: true)
== render "src/views/partials/editor.html.slang"
br
