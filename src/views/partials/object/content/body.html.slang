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
- partial "partials/object/content/attachments"
- if with_detail
  div.extra.text class=(is_deleted && "deleted" || nil)
    = emoji_html(html, object, emojis: object_emojis)
  - if object.quote_iri
    crystal:
      quote = object.quote?
      failed = false
      error_message = nil
    - partial "partials/object/content/quote"
  - if object.responds_to?(:poll?) && (poll = object.poll?)
    - partial "partials/object/content/poll"
- else
  div.extra.text class=(is_deleted && "deleted" || nil) data-controller="clickable-background" data-clickable-background-href-value=href
    = emoji_html(html, object, emojis: object_emojis)
  - if object.quote_iri
    crystal:
      quote = object.quote?
      failed = false
      error_message = nil
    - partial "partials/object/content/quote"
  - if object.responds_to?(:poll?) && (poll = object.poll?)
    - partial "partials/object/content/poll"
