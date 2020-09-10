article.nested.event id=anchor(_object) class=depth(_object)
  .label
    - if (_icon = _object.attributed_to.icon)
      img src=_icon
    - else
      i.user.icon
  .content
    crystal:
      if (_attachments = _object.attachments) && (_content = _object.content)
        unless _content.empty?
          _urls = XML.parse_html(_content).xpath_nodes("//img/@src").map(&.text)
          _attachments.reject! { |a| a.url.in?(_urls) }
        end
      end
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
      == s _object.content
    .meta
      a href=remote_actor_path(_object.attributed_to) = _object.attributed_to.display_name
      a href=remote_thread_path(_object) = _object.display_date
