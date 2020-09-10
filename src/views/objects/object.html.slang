section.ui.feed
  article.nested.event id=anchor(object)
    .label
      - if (_icon = object.try(&.attributed_to?).try(&.icon))
        img src=_icon
      - else
        i.user.icon
    .content
      - if (_attachments = object.attachments) && (_content = object.content)
        - _urls = XML.parse_html(_content).xpath_nodes("//img/@src").map(&.text)
        - _attachments.reject! { |a| a.url.in?(_urls) }
      - if _attachments && (_attachment = _attachments.shift?)
        - if _attachment.image?
          img.ui.large.fluid.image.attachment src=_attachment.url
        - unless _attachments.empty?
          .extra.images
            - _attachments.each do |_attachment|
              - if _attachment.image?
                img src=_attachment.url
      - extra = _attachment ? "extra" : nil
      .text class=extra
        == s object.content
      .meta
        - if (_attributed_to = object.attributed_to?)
          a href=remote_actor_path(_attributed_to) = _attributed_to.display_name
        a href=remote_thread_path(object) = object.display_date
