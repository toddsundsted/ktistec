.ui.actor.segments
  - if actor.blocked?
    .ui.blocked.segment
      = actor.display_name
      br: a href=actor.display_link = actor.account_uri
      br: em This actor is blocked!
  - else
    - image = actor.image.presence
    - style = image ? "background-image: url(#{actor.image});" : nil
    .ui.segment class=(!image ? "placeholder" : nil) style=style
      - if actor.icon.presence
        img src=actor.icon
      - else
        i.user.icon
    .ui.segment
      = actor.display_name
      br: a href=actor.display_link = actor.account_uri
      - if (summary = actor.summary.presence)
        br: == s summary
	.ui.segment
	  - if (attachments = actor.attachments.presence)
        table
          - attachments.each do |attachment|
            tr
              th.name == attachment.name
              td.value == maybe_wrap_link(attachment.value)
  - if (_account = env.account?) && _account.actor != actor
    .ui.basic.segment
      - if (_follow = ActivityPub::Activity::Follow.follows?(_account.actor, actor))
        == activity_button "Unfollow", outbox_path(_account), _follow.iri, type: "Undo"
      - elsif !actor.blocked?
        == activity_button "Follow", outbox_path(_account), actor.iri, button_class: "ui button primary"
      - if actor.blocked?
        == form_button "Unblock", unblock_actor_path(actor), button_class: "ui button"
      - elsif !_follow
        == form_button "Block", block_actor_path(actor), button_class: "ui button dangerous", button_data: {"modal": "block.actor"}
  - elsif !_account && actor.local?
    .ui.basic.segment
      == form_button "Follow", actor_remote_follow_path(actor), method: "GET", button_class: "ui button primary"
