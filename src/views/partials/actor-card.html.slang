- _account = env.account?
.ui.actor.card
  - if actor.blocked?
    .blocked.content
      em This actor is blocked!
  - else
    - style = actor_background_style(actor)
    .content class=(style ? nil : "placeholder") style=style
      = actor_icon(actor)
  .extra.content
    - if _account
      a.ui.header href=remote_actor_path(actor) = emoji_name(actor)
    - else
      .ui.header = emoji_name(actor)
    a.ui.link.truncated href=Ktistec::SafeURI.from?(actor.iri) = actor.handle
    - if _account
      - if env.request.path =~ /followers$/
        - if (_down = actor.down_at)
          crystal:
            _abs = _down.to_s("%B %d, %Y at %H:%M UTC")
            _rel = distance_of_time_in_words(_down)
          .meta.activity
            span.ui.label.broken
              | Down for
              time< datetime=_down.to_rfc3339 title=_abs = _rel
      - elsif env.request.path =~ /following$/
        crystal:
          _last_seen = _account.actor.last_activity_from(actor)
          _status = activity_status(_last_seen)
        .meta.activity
          - if _last_seen
            crystal:
              _abs = _last_seen.to_s("%B %d, %Y at %H:%M UTC")
              _rel = distance_of_time_in_words(_last_seen)
            - if _status == :active
              span.submeta
                | Last seen
                time<> datetime=_last_seen.to_rfc3339 title=_abs = _rel
                | ago
            - else
              span.ui.label class=(_status == :quiet ? "stale" : "broken")
                | Last seen
                time<> datetime=_last_seen.to_rfc3339 title=_abs = _rel
                | ago
          - else
            span.ui.label.broken No activity
  - if _account && _account.actor != actor
    .extra.content
      - if env.request.path =~ /followers$/ && (follow_relationship = actor.follows?(_account.actor)) && follow_relationship.pending? && (_follow = follow_relationship.activity?)
        = activity_button "Accept", outbox_path(_account), _follow.iri, button_class: "ui button accept"
        = activity_button "Reject", outbox_path(_account), _follow.iri, button_class: "ui button reject"
        = form_button "Block", block_actor_path(actor), button_class: "ui button dangerous", button_data: {"modal": "block.actor", "controller": "modal-action", "action": "click->modal-action#show"}
      - elsif (_follow = _account.actor.follows?(actor).try(&.activity?))
        = activity_button "Unfollow", outbox_path(_account), _follow.iri, type: "Undo"
      - else
        = activity_button "Follow", outbox_path(_account), actor.iri, button_class: "ui button primary"
        = form_button "Block", block_actor_path(actor), button_class: "ui button dangerous", button_data: {"modal": "block.actor", "controller": "modal-action", "action": "click->modal-action#show"}
  - elsif !_account && actor.local?
    .extra.content
      = form_button "Follow", actor_remote_follow_path(actor), method: "GET", button_class: "ui button primary"
