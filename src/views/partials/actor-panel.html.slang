- _account = env.account?
.ui.actor.segments
  - if actor.blocked?
    .ui.blocked.segment
      = actor.display_name
      br: a href=actor.display_link = actor.handle
      br: em This actor is blocked!
  - else
    - image = actor.image.presence
    - style = image ? "background-image: url(#{actor.image});" : nil
    .ui.attached.segment class=(!image ? "placeholder" : nil) style=style
      - if actor.icon.presence
        img src=actor.icon
      - else
        i.user.icon
    - if _account && actor.down?
      .ui.attached.tiny.warning.icon.message
        i.cloud.icon
        .content
          p
            | Due to failures to deliver posts to this actor, the
              actor is marked as down. There will be no further
              delivery attempts.
    .ui.basic.segment
      - if _account
        a href=remote_actor_path(actor) = actor.display_name
      - else
        span = actor.display_name
      br: a href=actor.display_link = actor.handle
      - if (summary = actor.summary.presence)
        br: == s summary
      - if (attachments = actor.attachments.presence)
        .ui.divider
        table
          - attachments.each do |attachment|
            tr
              th.name = attachment.name
              td.value == s wrap_link(attachment.value, length: 50)
  - if _account && _account.actor != actor
    .ui.basic.segment
      - if (_follow = _account.actor.follows?(actor).try(&.activity?))
        == activity_button "Unfollow", outbox_path(_account), _follow.iri, type: "Undo"
      - elsif !actor.blocked?
        == activity_button "Follow", outbox_path(_account), actor.iri, button_class: "ui button primary"
      - if actor.blocked?
        == form_button "Unblock", unblock_actor_path(actor), button_class: "ui button"
      - elsif !_follow
        == form_button "Block", block_actor_path(actor), button_class: "ui button dangerous", button_data: {"modal": "block.actor", "controller": "modal-action", "action": "click->modal-action#show"}
  - elsif !_account && actor.local?
    .ui.basic.segment
      == form_button "Follow", actor_remote_follow_path(actor), method: "GET", button_class: "ui button primary"
