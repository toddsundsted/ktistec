- _account = env.account?
- _emojis = Tag::Emoji.where(subject: actor)
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
      .actor-icon-container
        == actor_icon(actor)
        == actor_type(actor)
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
        a href=remote_actor_path(actor) == s Ktistec::Emoji.emojify(actor.display_name, _emojis)
      - else
        span == s Ktistec::Emoji.emojify(actor.display_name, _emojis)
      br: a href=actor.display_link = actor.handle
      - if (summary = actor.summary.presence)
        .ui.divider
        == s Ktistec::Emoji.emojify(summary, _emojis)
      - if (attachments = actor.attachments.presence)
        .ui.divider
        table
          - attachments.each do |attachment|
            tr
              th.name = attachment.name
              td.value == s wrap_link(attachment.value, length: 50)
  - if _account && _account.actor != actor
    - if (follow_relationship = actor.follows?(_account.actor))
      .ui.basic.segment
        - if follow_relationship.pending?
          details
            summary
              i.orange.clock.outline.icon
              | #{actor.display_name} wants to follow you
            - if (_follow = follow_relationship.activity?)
              .ui.orange.segment
                == activity_button "Accept", outbox_path(_account), _follow.iri, button_class: "ui green button"
                == activity_button "Reject", outbox_path(_account), _follow.iri, button_class: "ui red button"
        - elsif follow_relationship.accepted?
          details
            summary
              i.green.check.circle.icon
              | You accepted #{actor.display_name}'s follow request
            - if (_follow = follow_relationship.activity?)
              .ui.green.segment
                == activity_button "Reject Instead", outbox_path(_account), _follow.iri, type: "Reject", button_class: "ui red button"
        - elsif follow_relationship.rejected?
          details
            summary
              i.grey.times.circle.icon
              | You rejected #{actor.display_name}'s follow request
            - if (_follow = follow_relationship.activity?)
              .ui.grey.segment
                == activity_button "Accept Instead", outbox_path(_account), _follow.iri, type: "Accept", button_class: "ui green button"
    .ui.basic.segment
      - _follow = _account.actor.follows?(actor).try(&.activity?)
      - if _follow
        == activity_button "Unfollow", outbox_path(_account), _follow.iri, type: "Undo"
      - elsif !actor.blocked?
        == activity_button "Follow", outbox_path(_account), actor.iri, button_class: "ui button primary"
      - if actor.blocked?
        == form_button "Unblock", unblock_actor_path(actor), button_class: "ui button"
      - elsif !_follow
        == form_button "Block", block_actor_path(actor), button_class: "ui button dangerous", button_data: {"modal": "block.actor", "controller": "modal-action", "action": "click->modal-action#show"}
      == form_button "Refresh", refresh_remote_actor_path(actor), form_id: "actor-#{actor.id}-refresh-button", button_class: "ui button"
      .information
        - if _follow && (follow_relationship = _account.actor.follows?(actor))
          - if follow_relationship.pending?
            | Follow request is pending
          - elsif (accepted_or_rejected = follow_relationship.activity?.try(&.accepted_or_rejected?))
            - if follow_relationship.accepted?
              | Follow request accepted #{distance_of_time_in_words(accepted_or_rejected.created_at, Time.utc)} ago
            - elsif follow_relationship.rejected?
              | Follow request rejected #{distance_of_time_in_words(accepted_or_rejected.created_at, Time.utc)} ago
        br
        | Profile refreshed #{distance_of_time_in_words(actor.updated_at, Time.utc)} ago
  - elsif !_account && actor.local?
    .ui.basic.segment
      == form_button "Follow", actor_remote_follow_path(actor), method: "GET", button_class: "ui button primary"
