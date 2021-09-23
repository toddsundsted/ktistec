h1: a href=actor.display_link = actor.display_name
- if (icon = actor.icon)
  p: img.ui.small.image src=icon
- if (summary = actor.summary)
  p == s summary
- if (_account = env.account?) && _account.actor != actor
  - if (_follow = ActivityPub::Activity::Follow.follows?(_account.actor, actor))
    == activity_button "Unfollow", outbox_path(_account), _follow.iri, type: "Undo"
  - else
    == activity_button "Follow", outbox_path(_account), actor.iri, button_class: "ui button primary"
- elsif !_account && actor.local?
  form method="GET" action=actor_remote_follow_path(actor)
    input.ui.primary.button type="submit" value="Follow"
