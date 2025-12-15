- if with_detail
  == render "src/views/partials/object/content/attachments.html.slang"
  div.extra.text class=(is_deleted && "deleted" || nil)
    == s Ktistec::Emoji.emojify(html, object_emojis)
  - if object.responds_to?(:poll?) && (poll = object.poll?)
    == render "src/views/partials/object/content/poll.html.slang"
- else
  == render "src/views/partials/object/content/attachments.html.slang"
  div.extra.text class=(is_deleted && "deleted" || nil) data-controller="clickable-background" data-clickable-background-href-value=href
    == s Ktistec::Emoji.emojify(html, object_emojis)
  - if object.responds_to?(:poll?) && (poll = object.poll?)
    == render "src/views/partials/object/content/poll.html.slang"
