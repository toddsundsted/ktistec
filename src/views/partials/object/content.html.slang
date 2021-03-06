crystal:
  account = env.account?
  if (attachments = object.attachments) && (content = object.content)
    unless content.empty?
      urls = XML.parse_html(content).xpath_nodes("//img/@src").map(&.text)
      attachments.reject! { |a| a.url.in?(urls) }
    end
  end
  href = !object.draft? ? account ? remote_object_path(object) : object.display_link : nil
.content data-controller="clickable-background" data-action="click->clickable-background#click" data-clickable-background-href-value=href
  .summary
    - if object.draft?
      | draft created
      a.date = object.short_date
    - else
      - if account
        - if author != actor
          a.user> title=actor.account_uri href=remote_actor_path(actor) = actor.display_name
          | shared a post by
          a.user< title=author.account_uri href=remote_actor_path(author) = author.display_name
        - else
          a.user> title=author.account_uri href=remote_actor_path(author) = author.display_name
          | posted
        a.date title=object.display_date href=remote_object_path(object) = object.short_date
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
      img.ui.extra.image data-src=attachment.url src=attachment.url
    - unless attachments.empty?
      .extra.images
        - attachments.each do |attachment|
          - if attachment.image?
            img.ui.image data-src=attachment.url src=attachment.url
  .extra.text
    == s object.content
  - if with_detail && account
    - unless (activities = object.activities(inclusion: [ActivityPub::Activity::Announce, ActivityPub::Activity::Like])).empty?
      .extra.detail
        - activities.each do |activity|
          - if activity.responds_to?(:actor?) && activity.actor?
            a href=remote_actor_path(activity.actor)
              - if (icon = activity.actor.icon)
                img.ui.avatar.image data-actor-id=activity.actor.id src=icon
              - else
                i.user.icon
              - case activity
              - when ActivityPub::Activity::Announce
                i.share.icon
              - when ActivityPub::Activity::Like
                i.star.icon
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
      - object.with_statistics!.with_replies_count!
      - if (c = object.replies_count) > 0 || object.in_reply_to?
        a href=remote_thread_path(object)
          button.ui.mini.iconic.button
            i.comments.icon
            | Thread
      a href=reply_path(object)
        button.ui.mini.iconic.button
          i.reply.icon
          = pluralize(c, "Reply")
      - if (c = object.likes_count) > 0 && (to_undo = account.actor.find_like_for(object))
        == activity_button(outbox_path(account), to_undo.iri, "Undo", button_class: "mini blue iconic") do
          i.star.icon
          = pluralize(c, "Like")
      - else
        == activity_button(outbox_path(account), object.iri, "Like", button_class: "mini iconic") do
          i.star.icon
          = pluralize(c, "Like")
      - if (c = object.announces_count) > 0 && (to_undo = account.actor.find_announce_for(object))
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
        a href=edit_object_path(object)
          button.ui.mini.iconic.button
            i.edit.icon
            | Edit
        == activity_button(outbox_path(account), object.iri, "Delete", button_class: "mini dangerous iconic", button_attrs: {"data-modal": "delete"}) do
          i.trash.icon
          | Delete
    - else
      - object.with_statistics!.with_replies_count!(approved_by: object.attributed_to)
      - if (c = object.replies_count) > 0 || object.in_reply_to?.try(&.approved_by?(object.attributed_to))
        a href=thread_path(object)
          button.ui.mini.iconic.button
            i.comments.icon
            | Thread
      - if (c = object.likes_count) > 0
        button.ui.mini.iconic.button
          i.star.icon
          = pluralize(c, "Like")
      - if (c = object.announces_count) > 0
        button.ui.mini.iconic.button
          i.share.icon
          = pluralize(c, "Share")
