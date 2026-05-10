h1 New Post
- if (in_reply_to = object.in_reply_to?)
  section.ui.feed data-controller="icon-load-error"
    - Ktistec::ViewHelper.object_partial(env, in_reply_to, content_io: content_io)
- Slang.embed("src/views/partials/editor.html.slang", content_io)
br
