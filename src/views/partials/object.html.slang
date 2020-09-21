.label
  - if _author.icon
    - if _author != _actor && _actor.icon
      img src=_actor.icon
    img src=_author.icon
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
      img.ui.image.attachment src=_attachment.url
    - unless _attachments.empty?
      .extra.images
        - _attachments.each do |_attachment|
          - if _attachment.image?
            img src=_attachment.url
  .text class=(_attachment ? "extra" : nil)
    == s _object.content
  .meta
    - if (__account = env.current_account?)
      a href=remote_actor_path(_author) = _author.display_name
      a href=remote_thread_path(_object) = _object.display_date
    - else
      a href=_author.display_link = _author.display_name
      a href=_object.display_link = _object.display_date
