- _actor = activity.actor
- _author = activity.object.attributed_to? || _actor
- _object = activity.object
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
    a href=_author.display_link = _author.display_name
    a href=_object.display_link = _object.display_date
