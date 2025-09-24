- if with_detail
  == render "src/views/partials/object/content/attachments.html.slang"
  div.extra.text class=(is_deleted && "deleted" || nil)
    == s html
- else
  == render "src/views/partials/object/content/attachments.html.slang"
  div.extra.text class=(is_deleted && "deleted" || nil) data-controller="clickable-background" data-clickable-background-href-value=href
    == s html
