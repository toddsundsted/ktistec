crystal:
  account = env.account?
  timezone = account.try { |account| Time::Location.load(account.timezone) }
  href = !object.draft? ? account ? remote_object_path(object) : object.display_link : nil
  type = object.type.split("::").last.downcase
  translation = object.translations.first?
  if (content = translation.try(&.content).presence || object.content.presence)
    html = (object.media_type == "text/markdown") ? markdown_to_html(content) : content
  end
  if (attachments = object.attachments)
    if html
      urls = XML.parse_html(html).xpath_nodes("//img/@src").map(&.text)
      attachments.reject! { |a| a.url.in?(urls) }
    end
  end
  is_blocked = object.blocked? || author.blocked? || actor.blocked?
  is_deleted = object.deleted? || author.deleted? || actor.deleted?
.content data-controller="image-viewer" data-action="click->image-viewer#handleClick"
  .summary
    - if object.draft?
      | draft created
      a.date< = object.short_date(timezone)
    - else
      - if account
        - if author != actor
          a.user> data-turbo-frame="_top" title=actor.handle href=remote_actor_path(actor) = actor.display_name
          | shared a #{type} by
          a.user< data-turbo-frame="_top" title=author.handle href=remote_actor_path(author) = author.display_name
        - else
          a.user> data-turbo-frame="_top" title=author.handle href=remote_actor_path(author) = author.display_name
          | posted
        a.date< data-turbo-frame="_top" title=object.display_date(timezone) href=remote_object_path(object) = object.short_date(timezone)
      - else
        - if author != actor
          a.user> data-turbo-frame="_top" title=actor.handle href=actor.display_link = actor.display_name
          | shared a #{type} by
          a.user< data-turbo-frame="_top" title=author.handle href=author.display_link = author.display_name
        - else
          a.user> data-turbo-frame="_top" title=author.handle href=author.display_link = author.display_name
          | posted
        a.date< data-turbo-frame="_top" title=object.display_date(timezone) href=object.display_link = object.short_date(timezone)
  - unless is_blocked
    - if (name = translation.try(&.name).presence || object.name.presence)
      .extra.text
        - if object.external?
          a href=object.display_link target="_blank"
            strong = name
        - else
          strong = name
    - if (summary = translation.try(&.summary).presence || object.summary.presence)
      details open=with_detail
        summary
          - if object.sensitive
            i.red.eye.slash.icon
          = t summary
        == render "src/views/partials/object/content/body.html.slang"
    - else
      == render "src/views/partials/object/content/body.html.slang"
    - if with_detail && account
      crystal:
        hashtags = object.hashtags.map(&.name.downcase).uniq
        mentions = object.mentions.map(&.name.downcase).uniq
        no_duplicate_handles = (mentions.map(&.split("@").first).uniq.size == mentions.size)
      - unless hashtags.empty? && mentions.empty?
        .extra.detail
          .ui.labels
            - hashtags.each do |hashtag|
              a.ui.small.label data-turbo-frame="_top" href=hashtag_path(hashtag) ##{hashtag}
            - mentions.each do |mention|
              - handle = no_duplicate_handles ? mention.split("@").first : mention
              a.ui.small.label data-turbo-frame="_top" href=mention_path(mention) @#{handle}
      - unless (activities = object.activities(inclusion: [ActivityPub::Activity::Announce, ActivityPub::Activity::Like])).empty?
        .extra.detail
          - activities.each do |activity|
            - if activity.actor?
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
  - if author.deleted? || actor.deleted?
    .extra.text
      em This actor is deleted!
  - elsif author.blocked? || actor.blocked?
    .extra.text
      em This actor is blocked!
  - elsif object.deleted?
    .extra.text
      em This content is deleted!
  - elsif object.blocked?
    .extra.text
      em This content is blocked!
  .meta
    - if account && object.deleted?
      - if object.cached?
        a.ui.mini.iconic.button.source target="_blank" href=object.display_link
          i.external.arrow.icon
          | Source
    - elsif account && object.blocked?
      == form_button unblock_object_path(object), button_class: "ui button mini iconic" do
        i.times.icon
        | Unblock
      - if object.cached?
        a.ui.mini.iconic.button.source target="_blank" href=object.display_link
          i.external.arrow.icon
          | Source
    - elsif account && (author.blocked? || actor.blocked?)
      - if object.cached?
        a.ui.mini.iconic.button.source target="_blank" href=object.display_link
          i.external.arrow.icon
          | Source
    - elsif account && object.draft?
      a data-turbo-frame="_top" href=edit_object_path(object)
        button.ui.mini.iconic.button
          i.edit.icon
          | Edit
      == form_button object_path(object), method: "DELETE", button_class: "ui mini dangerous iconic button", button_data: {"modal" => "delete", "controller" => "modal-action", "action" => "click->modal-action#show"} do
        i.trash.icon
        | Delete
    - elsif account
      - object.with_statistics!.with_replies_count!
      - if (c = object.replies_count) > 0 || object.in_reply_to_iri.presence || with_detail
        - unless for_thread.presence
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
      - if translation
        == form_button clear_translation_object_path(object), button_class: "ui button mini purple iconic" do
          i.paper.plane.icon
          | Clear
      - elsif Ktistec.translator
        - if (source = account.language) && (target = object.language)
          - if source.split("-").first != target.split("-").first
            == form_button create_translation_object_path(object), button_class: "ui button mini iconic" do
              i.paper.plane.icon
              | Translate
      - if object.in_reply_to? && for_thread.try(&.first.attributed_to?) == account.actor
        - if object.approved_by?(account.actor)
          form.ui.form method="POST" action=unapprove_path(object) data-controller="checkbox-submit"
            input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
            .ui.mini.toggle.checkbox.checked
              input id="object-#{object.id}-public" type="checkbox" name="public" checked="checked" data-action="change->checkbox-submit#change"
              label for="object-#{object.id}-public" Public
        - else
          form.ui.form method="POST" action=approve_path(object) data-controller="checkbox-submit"
            input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
            .ui.mini.toggle.checkbox
              input id="object-#{object.id}-public" type="checkbox" name="public" data-action="change->checkbox-submit#change"
              label for="object-#{object.id}-public" Public
      - if author == account.actor
        a data-turbo-frame="_top" href=edit_object_path(object)
          button.ui.mini.iconic.button
            i.edit.icon
            | Edit
        == activity_button(outbox_path(account), object.iri, "Delete", button_class: "ui button mini dangerous iconic", button_data: {"modal": "delete", "controller": "modal-action", "action": "click->modal-action#show"}) do
          i.trash.icon
          | Delete
      - elsif announce.nil? && like.nil?
        == form_button block_object_path(object), button_class: "ui button mini dangerous iconic", button_data: {"modal": "block.object", "controller": "modal-action", "action": "click->modal-action#show"} do
          i.times.icon
          | Block
      - if object.cached?
        a.ui.mini.iconic.button.source target="_blank" href=object.display_link
          i.external.arrow.icon
          | Source
    - elsif object.local?
      - object.with_statistics!.with_replies_count!(approved_by: object.attributed_to)
      - if (c = object.replies_count) > 0 || object.in_reply_to?.try(&.approved_by?(object.attributed_to))
        a data-turbo-frame="_top" href=thread_path(object)
          button.ui.mini.iconic.button
            i.comments.icon
            | Thread
      a data-turbo-frame="_top" href=object_remote_reply_path(object)
        button.ui.mini.iconic.button
          i.reply.icon
          = pluralize(c, "Reply")
      a data-turbo-frame="_top" href=object_remote_like_path(object)
        button.ui.mini.iconic.button
          i.thumbs.up.icon
          = pluralize(object.likes_count, "Like")
      a data-turbo-frame="_top" href=object_remote_share_path(object)
        button.ui.mini.iconic.button
          i.share.icon
          = pluralize(object.announces_count, "Share")
