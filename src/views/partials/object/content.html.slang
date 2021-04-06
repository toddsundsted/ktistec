.content
  crystal:
    object.with_statistics!.with_replies_count!
    account = env.account?
    if (attachments = object.attachments) && (content = object.content)
      unless content.empty?
        _urls = XML.parse_html(content).xpath_nodes("//img/@src").map(&.text)
        attachments.reject! { |a| a.url.in?(_urls) }
      end
    end
  .summary
    - if object.draft?
      | draft created
      a.date = object.display_date
    - else
      - if account
        - if author != actor
          a.user> title=actor.account_uri href=remote_actor_path(actor) = actor.display_name
          | shared a post by
          a.user< title=author.account_uri href=remote_actor_path(author) = author.display_name
        - else
          a.user> title=author.account_uri href=remote_actor_path(author) = author.display_name
          | posted
        a.date title=object.display_date href=remote_thread_path(object) = object.short_date
      - else
        - if author != actor
          a.user> title=actor.account_uri href=actor.display_link = actor.display_name
          | shared a post by
          a.user< title=author.account_uri href=author.display_link = author.display_name
        - else
          a.user> title=author.account_uri href=author.display_link = author.display_name
          | posted
        a.date title=object.display_date href=object.display_link = object.short_date
  - if attachments && (attachment = attachments.shift?)
    - if attachment.image?
      img.ui.extra.image.attachment src=attachment.url
    - unless attachments.empty?
      .extra.images
        - attachments.each do |attachment|
          - if attachment.image?
            img src=attachment.url
  .extra.text
    == s object.content
  .meta
    - if account && object.draft?
      a href=edit_object_path(object)
        button.ui.mini.iconic.button
          i.edit.icon
          | Edit
      form.ui.form method="POST" action=object_path(object)
        input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
        input type="hidden" name="_method" value="delete"
        button.ui.mini.dangerous.iconic.button type="submit" data-modal="delete"
          i.trash.icon
          | Delete
    - elsif account
      - c = object.replies_count
      a href=replies_path(object)
        button.ui.mini.iconic.button
          i.reply.icon
          = pluralize(c, "Reply")
      - if (c = object.likes_count) > 0 && (to_undo = account.actor.find_like_in_outbox(object))
        == activity_button(outbox_path(account), to_undo.iri, "Undo", button_class: "mini blue iconic") do
          i.star.icon
          = pluralize(c, "Like")
      - else
        == activity_button(outbox_path(account), object.iri, "Like", button_class: "mini iconic") do
          i.star.icon
          = pluralize(c, "Like")
      - if (c = object.announces_count) > 0 && (to_undo = account.actor.find_announce_in_outbox(object))
        == activity_button(outbox_path(account), to_undo.iri, "Undo", button_class: "mini blue iconic") do
          i.share.icon
          = pluralize(c, "Share")
      - else
        == activity_button(outbox_path(account), object.iri, "Announce", button_class: "mini iconic") do
          i.share.icon
          = pluralize(c, "Share")
      - if object.in_reply_to? && for_thread.try(&.first.attributed_to?) == account.actor
        - if object.approved_by?(account.actor)
          form.ui.form method="POST" action=unapprove_path(object)
            input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
            .ui.mini.toggle.checkbox.checked data-action="click->partial-update#submit"
              input type="checkbox" name="public" checked="checked"
              label Public
        - else
          form.ui.form method="POST" action=approve_path(object)
            input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
            .ui.mini.toggle.checkbox data-action="click->partial-update#submit"
              input type="checkbox" name="public"
              label Public
      - if author == account.actor
        == activity_button(outbox_path(account), object.iri, "Delete", button_class: "mini dangerous iconic", button_attrs: {"data-modal": "delete"}) do
          i.trash.icon
          | Delete
    - else
      - if (c = object.likes_count) > 0
        button.ui.mini.iconic.button
          i.star.icon
          = pluralize(c, "Like")
      - if (c = object.announces_count) > 0
        button.ui.mini.iconic.button
          i.share.icon
          = pluralize(c, "Share")
