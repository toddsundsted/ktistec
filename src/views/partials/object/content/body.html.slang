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
      attachments.reject!(&.url.in?(urls))
    end
  end
- Slang.embed("src/views/partials/object/content/attachments.html.slang", content_io)
- if with_detail
  div.extra.text class=(is_deleted && "deleted" || nil)
    = s Ktistec::Emoji.emojify(html, object_emojis)
  - if object.quote_iri
    crystal:
      quote = object.quote?
      failed = false
      error_message = nil
    - Slang.embed("src/views/partials/object/content/quote.html.slang", content_io)
  - if object.responds_to?(:poll?) && (poll = object.poll?)
    - Slang.embed("src/views/partials/object/content/poll.html.slang", content_io)
- else
  div.extra.text class=(is_deleted && "deleted" || nil) data-controller="clickable-background" data-clickable-background-href-value=href
    = s Ktistec::Emoji.emojify(html, object_emojis)
  - if object.quote_iri
    crystal:
      quote = object.quote?
      failed = false
      error_message = nil
    - Slang.embed("src/views/partials/object/content/quote.html.slang", content_io)
  - if object.responds_to?(:poll?) && (poll = object.poll?)
    - Slang.embed("src/views/partials/object/content/poll.html.slang", content_io)
