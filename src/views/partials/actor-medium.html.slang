h1: a href=actor.display_link = actor.display_name
- if (icon = actor.icon)
  p: img.ui.small.image src=icon
- if (summary = actor.summary)
  p == s summary
- if (_account = env.current_account?)
  - if (_follow = ActivityPub::Activity::Follow.follows?(_account.actor, actor))
    form method="POST" action=outbox_path(_account)
      input type="hidden" name="type" value="Undo"
      input type="hidden" name="object" value=_follow.iri
      input.ui.button type="submit" value="Unfollow"
  - else
    form method="POST" action=outbox_path(_account)
      input type="hidden" name="type" value="Follow"
      input type="hidden" name="object" value=actor.iri
      input.ui.primary.button type="submit" value="Follow"
