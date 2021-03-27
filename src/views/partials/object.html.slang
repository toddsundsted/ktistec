.label
  - if _author != _actor
    - if (icon = _actor.icon)
      img data-actor-id=_actor.id src=icon
    - else
      i.user.icon
  - if (icon = _author.icon)
    img data-actor-id=_author.id src=icon
  - else
    i.user.icon
.content
  crystal:
    _object.with_statistics!.with_replies_count!
    __account = env.account?
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
    - if __account && _object.draft?
      a href=edit_object_path(_object)
        button.ui.mini.iconic.button
          i.edit.icon
          | Edit
      form.ui.form method="POST" action=object_path(_object)
        input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
        input type="hidden" name="_method" value="delete"
        button.ui.mini.dangerous.iconic.button type="submit" data-modal="delete"
          i.trash.icon
          | Delete
    - elsif __account
      - c = _object.replies_count
      a href=replies_path(_object)
        button.ui.mini.iconic.button
          i.reply.icon
          = pluralize(c, "Reply")
      - if (c = _object.likes_count) > 0 && (to_undo = __account.actor.find_like_in_outbox(_object))
        == activity_button(outbox_path(__account), to_undo.iri, "Undo", button_class: "mini blue iconic") do
          i.star.icon
          = pluralize(c, "Like")
      - else
        == activity_button(outbox_path(__account), _object.iri, "Like", button_class: "mini iconic") do
          i.star.icon
          = pluralize(c, "Like")
      - if (c = _object.announces_count) > 0 && (to_undo = __account.actor.find_announce_in_outbox(_object))
        == activity_button(outbox_path(__account), to_undo.iri, "Undo", button_class: "mini blue iconic") do
          i.share.icon
          = pluralize(c, "Share")
      - else
        == activity_button(outbox_path(__account), _object.iri, "Announce", button_class: "mini iconic") do
          i.share.icon
          = pluralize(c, "Share")
      - if env.request.path =~ /thread$/ && _object.in_reply_to_iri
        - if _object.approved_by?(__account.actor)
          form.ui.form method="POST" action=unapprove_path(_object)
            input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
            .ui.mini.toggle.checkbox.checked
              input type="checkbox" name="public" checked="checked"
              label Public
        - else
          form.ui.form method="POST" action=approve_path(_object)
            input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
            .ui.mini.toggle.checkbox
              input type="checkbox" name="public"
              label Public
      - if _author == __account.actor
        == activity_button(outbox_path(__account), _object.iri, "Delete", button_class: "mini dangerous iconic", button_attrs: {"data-modal": "delete"}) do
          i.trash.icon
          | Delete
    - else
      - if (c = _object.likes_count) > 0
        button.ui.mini.iconic.button
          i.star.icon
          = pluralize(c, "Like")
      - if (c = _object.announces_count) > 0
        button.ui.mini.iconic.button
          i.share.icon
          = pluralize(c, "Share")
  .meta
    - if __account
      a href=remote_actor_path(_author) = _author.display_name
      a href=remote_thread_path(_object) = _object.display_date
    - else
      a href=_author.display_link = _author.display_name
      a href=_object.display_link = _object.display_date
