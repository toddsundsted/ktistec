- if attachments && (attachment = attachments.shift?)
  - if attachment.image?
    img.ui.extra.attachment.image src=attachment.url alt=attachment.caption style="object-position: #{attachment.css_object_position}"
  - elsif attachment.video?
    video.ui.extra.attachment.video src=attachment.url controls=true
  - elsif attachment.audio?
    audio.ui.extra.attachment.audio src=attachment.url controls=true
  - unless attachments.empty?
    .extra.media
      - attachments.each do |attachment|
        - if attachment.image?
          img.ui.attachment.image src=attachment.url alt=attachment.caption style="object-position: #{attachment.css_object_position}"
        - elsif attachment.video?
          video.ui.attachment.video src=attachment.url controls=true
        - elsif attachment.audio?
          audio.ui.attachment.audio src=attachment.url controls=true
