- if with_detail
  == render "src/views/partials/object/content/attachments.html.slang"
  div.extra.text class=(is_deleted && "deleted" || nil)
    == s Ktistec::Emoji.emojify(html, object_emojis)
  - if object.quote_iri && !ActivityPub::Object.find?(quote: object)
    == _view_src_views_partials_object_content_quote_html_slang(env, object, object.quote?, false)
  - if object.responds_to?(:poll?) && (poll = object.poll?)
    == _view_src_views_partials_object_content_poll_html_slang(env, poll, object_emojis, timezone)
- else
  == render "src/views/partials/object/content/attachments.html.slang"
  div.extra.text class=(is_deleted && "deleted" || nil) data-controller="clickable-background" data-clickable-background-href-value=href
    == s Ktistec::Emoji.emojify(html, object_emojis)
  - if object.quote_iri && !ActivityPub::Object.find?(quote: object)
    == _view_src_views_partials_object_content_quote_html_slang(env, object, object.quote?, false)
  - if object.responds_to?(:poll?) && (poll = object.poll?)
    == _view_src_views_partials_object_content_poll_html_slang(env, poll, object_emojis, timezone)
