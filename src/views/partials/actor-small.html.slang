a.card href=actor.iri
  .content
    .header= actor.display_name
    .meta= actor.username
  .extra.content
    - if (icon = actor.icon)
      img.ui.mini.image src=icon
    - else
      i.ui.user.icon
    - if (_account = env.account?)
      - if (_follow = ActivityPub::Activity::Follow.follows?(_account.actor, actor))
        form.right.floated method="POST" action=actor_relationships_path(_account, "outbox")
          input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
          input type="hidden" name="type" value="Undo"
          input type="hidden" name="object" value=_follow.iri
          input.ui.mini.primary.button type="submit" value="Unfollow"
      - else
        form.right.floated method="POST" action=actor_relationships_path(_account, "outbox")
          input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
          input type="hidden" name="type" value="Follow"
          input type="hidden" name="object" value=actor.iri
          input.ui.mini.primary.button type="submit" value="Follow"
