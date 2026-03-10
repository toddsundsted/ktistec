crystal:
  account = env.account?
  href = !object.draft? ? account ? remote_object_path(object) : object.display_link : nil
  object_emojis = Tag::Emoji.where(subject: object)
  translation = object.translations.first?
  if (content = translation.try(&.content).presence || object.content.presence)
    html = (object.media_type == "text/markdown") ? markdown_to_html(content) : content
  end
  if (attachments = object.attachments.dup)  # don't modify the object
    if html
      urls = XML.parse_html(html).xpath_nodes("//img/@src").map(&.text)
      attachments.reject! { |a| a.url.in?(urls) }
    end
  end
== render "src/views/partials/object/content/attachments.html.slang"
- if with_detail
  div.extra.text class=(is_deleted && "deleted" || nil)
    == s Ktistec::Emoji.emojify(html, object_emojis)
  - if object.quote_iri
    == _view_src_views_partials_object_content_quote_html_slang(env, object, object.quote?, false, nil, show_quote)
  - if object.responds_to?(:poll?) && (poll = object.poll?)
    == _view_src_views_partials_object_content_poll_html_slang(env, poll, object_emojis, timezone)
- else
  div.extra.text class=(is_deleted && "deleted" || nil) data-controller="clickable-background" data-clickable-background-href-value=href
    == s Ktistec::Emoji.emojify(html, object_emojis)
  - if object.quote_iri
    == _view_src_views_partials_object_content_quote_html_slang(env, object, object.quote?, false, nil, show_quote)
  - if object.responds_to?(:poll?) && (poll = object.poll?)
    == _view_src_views_partials_object_content_poll_html_slang(env, poll, object_emojis, timezone)
