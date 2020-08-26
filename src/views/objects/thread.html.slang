section.ui.feed
  - thread.each do |reply|
   article.nested.event id=anchor(reply) class=depth(reply)
      .label
        - if (_icon = reply.attributed_to.icon)
          img src=_icon
        - else
          i.user.icon
      .content
        - if (_attachments = reply.attachments) && (_attachment = _attachments.shift?)
          - if _attachment.image?
            img.ui.large.fluid.image.attachment src=_attachment.url
          - unless _attachments.empty?
            .extra.images
              - _attachments.each do |_attachment|
                - if _attachment.image?
                  img src=_attachment.url
        - extra = _attachment ? "extra" : nil
        .text class=extra
          == s reply.content
        .meta
          a href=remote_actor_path(reply.attributed_to) = reply.attributed_to.display_name
          a href=remote_thread_path(reply) = reply.display_date
