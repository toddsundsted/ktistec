.label
  - if _author != _actor
    - if _actor.icon
      img src=_actor.icon
    - else
      i.user.icon
  - if _author.icon
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
    - if (__account = env.account?)
      a href=remote_actor_path(_author) = _author.display_name
      a href=remote_thread_path(_object) = _object.display_date
    - else
      a href=_author.display_link = _author.display_name
      a href=_object.display_link = _object.display_date
  .meta
    - if __account
      a href=replies_path(_object)
        button.ui.mini.iconic.button
          i.reply.icon
          | Reply
      - if (c = _object.likes) > 0 && (to_undo = __account.actor.in_outbox?(_object, ActivityPub::Activity::Like))
        form.ui.form method="POST" action=actor_relationships_path(__account, "outbox")
          input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
          input type="hidden" name="object" value=to_undo.iri
          input type="hidden" name="type" value="Undo"
          button.ui.mini.blue.iconic.button type="submit"
            i.star.icon
            - if c == 1
              | 1 Like
            - else
              | #{c} Likes
      - else
        form.ui.form method="POST" action=actor_relationships_path(__account, "outbox")
          input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
          input type="hidden" name="object" value=_object.iri
          input type="hidden" name="type" value="Like"
          button.ui.mini.iconic.button type="submit"
            i.star.icon
            - if c == 0
              | Like
            - elsif c == 1
              | 1 Like
            - else
              | #{c} Likes
      - if (c = _object.announces) > 0 && (to_undo = __account.actor.in_outbox?(_object, ActivityPub::Activity::Announce))
        form.ui.form method="POST" action=actor_relationships_path(__account, "outbox")
          input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
          input type="hidden" name="object" value=to_undo.iri
          input type="hidden" name="type" value="Undo"
          button.ui.mini.blue.iconic.button type="submit"
            i.share.icon
            - if c == 1
              | 1 Share
            - else
              | #{c} Shares
      - else
        form.ui.form method="POST" action=actor_relationships_path(__account, "outbox")
          input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
          input type="hidden" name="object" value=_object.iri
          input type="hidden" name="type" value="Announce"
          button.ui.mini.iconic.button type="submit"
            i.share.icon
            - if c == 0
              | Share
            - elsif c == 1
              | 1 Share
            - else
              | #{c} Shares
      - if _author == __account.actor
        form.ui.form method="POST" action=actor_relationships_path(__account, "outbox")
          input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
          input type="hidden" name="object" value=_object.iri
          input type="hidden" name="type" value="Delete"
          button.ui.mini.dangerous.iconic.button type="submit" data-modal="delete"
            i.trash.icon
            | Delete
    - else
      - if (c = _object.likes) > 0
        button.ui.mini.iconic.button
          i.star.icon
          = c > 1 ? "#{c} Likes" : "1 Like"
      - if (c = _object.announces) > 0
        button.ui.mini.iconic.button
          i.share.icon
          = c > 1 ? "#{c} Shares" : "1 Share"
