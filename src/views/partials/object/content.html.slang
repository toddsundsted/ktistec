crystal:
  account = env.account?
  if (attachments = object.attachments) && (content = object.content)
    unless content.empty?
      urls = XML.parse_html(content).xpath_nodes("//img/@src").map(&.text)
      attachments.reject! { |a| a.url.in?(urls) }
    end
  end
  href = !object.draft? ? account ? remote_object_path(object) : object.display_link : nil
  type = object.type.split("::").last.downcase
.content data-controller="image-gallery clickable-background" data-action="click->clickable-background#click" data-clickable-background-href-value=href
  - timezone = account.try { |account| Time::Location.load(account.timezone) }
  .summary
    - if object.draft?
      | draft created
      a.date = object.short_date(timezone)
    - else
      - if account
        - if author != actor
          a.user> data-turbo-frame="_top" title=actor.account_uri href=remote_actor_path(actor) = actor.display_name
          | shared a #{type} by
          a.user< data-turbo-frame="_top" title=author.account_uri href=remote_actor_path(author) = author.display_name
        - else
          a.user> data-turbo-frame="_top" title=author.account_uri href=remote_actor_path(author) = author.display_name
          | posted
        a.date data-turbo-frame="_top" title=object.display_date(timezone) href=remote_object_path(object) = object.short_date(timezone)
      - else
        - if author != actor
          a.user> data-turbo-frame="_top" title=actor.account_uri href=actor.display_link = actor.display_name
          | shared a #{type} by
          a.user< data-turbo-frame="_top" title=author.account_uri href=author.display_link = author.display_name
        - else
          a.user> data-turbo-frame="_top" title=author.account_uri href=author.display_link = author.display_name
          | posted
        a.date data-turbo-frame="_top" title=object.display_date(timezone) href=object.display_link = object.short_date(timezone)
  - if object.blocked?
    .extra.text
      em This object is blocked!
  - else
    - if attachments && (attachment = attachments.shift?)
      - if attachment.image?
        img.ui.extra.attachment.image src=attachment.url
      - unless attachments.empty?
        .extra.images
          - attachments.each do |attachment|
            - if attachment.image?
              img.ui.attachment.image src=attachment.url
    - if (name = object.name)
      .extra.text
        - if object.external?
          a href=object.display_link target="_blank" : strong = name
        - else
          strong = name
    .extra.text
      == s object.content
    - if with_detail && account
      - unless (activities = object.activities(inclusion: [ActivityPub::Activity::Announce, ActivityPub::Activity::Like])).empty?
        .extra.detail
          - activities.each do |activity|
            - if activity.responds_to?(:actor?) && activity.actor?
              a data-turbo-frame="_top" href=remote_actor_path(activity.actor)
                - if (icon = activity.actor.icon)
                  img.ui.avatar.image data-actor-id=activity.actor.id src=icon
                - else
                  i.user.icon
                - case activity
                - when ActivityPub::Activity::Announce
                  i.share.icon
                - when ActivityPub::Activity::Like
                  i.thumbs.up.icon
  .meta
    - if account && object.blocked?
      == form_button unblock_object_path(object), button_class: "ui button mini iconic" do
        i.times.icon
        | Unblock
    - elsif account && object.draft?
      a data-turbo-frame="_top" href=edit_object_path(object)
        button.ui.mini.iconic.button
          i.edit.icon
          | Edit
      == form_button object_path(object), method: "DELETE", button_class: "ui mini dangerous iconic button", button_data: {"modal" => "delete"} do
        i.trash.icon
        | Delete
    - elsif account
      - object.with_statistics!.with_replies_count!
      - if (c = object.replies_count) > 0 || object.in_reply_to?
        a data-turbo-frame="_top" href=remote_thread_path(object)
          button.ui.mini.iconic.button
            i.comments.icon
            | Thread
      a data-turbo-frame="_top" href=reply_path(object)
        button.ui.mini.iconic.button
          i.reply.icon
          = pluralize(c, "Reply")
      - if (c = object.likes_count) > 0 && (like = account.actor.find_like_for(object))
        == activity_button(outbox_path(account), like.iri, "Undo", button_class: "ui button mini blue iconic") do
          i.thumbs.up.icon
          = pluralize(c, "Like")
      - else
        == activity_button(outbox_path(account), object.iri, "Like", button_class: "ui button mini iconic") do
          i.thumbs.up.icon
          = pluralize(c, "Like")
      - if (c = object.announces_count) > 0 && (announce = account.actor.find_announce_for(object))
        == activity_button(outbox_path(account), announce.iri, "Undo", button_class: "ui button mini blue iconic") do
          i.share.icon
          = pluralize(c, "Share")
      - else
        == activity_button(outbox_path(account), object.iri, "Announce", button_class: "ui button mini iconic") do
          i.share.icon
          = pluralize(c, "Share")
      - if object.in_reply_to? && for_thread.try(&.first.attributed_to?) == account.actor
        - if object.approved_by?(account.actor)
          form.ui.form method="POST" action=unapprove_path(object) data-controller="checkbox-submit"
            input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
            .ui.mini.toggle.checkbox.checked
              input type="checkbox" name="public" checked="checked" data-action="change->checkbox-submit#change"
              label Public
        - else
          form.ui.form method="POST" action=approve_path(object) data-controller="checkbox-submit"
            input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
            .ui.mini.toggle.checkbox
              input type="checkbox" name="public" data-action="change->checkbox-submit#change"
              label Public
      - if author == account.actor
        a data-turbo-frame="_top" href=edit_object_path(object)
          button.ui.mini.iconic.button
            i.edit.icon
            | Edit
        == activity_button(outbox_path(account), object.iri, "Delete", button_class: "ui button mini dangerous iconic", button_data: {"modal": "delete"}) do
          i.trash.icon
          | Delete
      - elsif announce.nil? && like.nil?
        == form_button block_object_path(object), button_class: "ui button mini dangerous iconic", button_data: {"modal": "block.object"} do
          i.times.icon
          | Block
    - else
      - object.with_statistics!.with_replies_count!(approved_by: object.attributed_to)
      - if (c = object.replies_count) > 0 || object.in_reply_to?.try(&.approved_by?(object.attributed_to))
        a data-turbo-frame="_top" href=thread_path(object)
          button.ui.mini.iconic.button
            i.comments.icon
            | Thread
      - if (c = object.likes_count) > 0
        button.ui.mini.iconic.button
          i.thumbs.up.icon
          = pluralize(c, "Like")
      - if (c = object.announces_count) > 0
        button.ui.mini.iconic.button
          i.share.icon
          = pluralize(c, "Share")
