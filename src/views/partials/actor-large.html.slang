.ui.actor-large.segments
  - image = actor.image.presence && "background-image: url(#{actor.image});"
  .ui.segment class=(actor.image.presence || "placeholder") style=image
    - if actor.icon.presence
      img src=actor.icon
    - else
      i.user.icon
  .ui.segment
    = actor.display_name
    br: a href=actor.display_link = actor.account_uri
    br: == s actor.summary
  - if (_account = env.account?) && _account.actor != actor
    .ui.basic.segment
      - if (_account = env.account?) && _account.actor != actor
        - if (_follow = ActivityPub::Activity::Follow.follows?(_account.actor, actor))
          form method="POST" action=outbox_path(_account)
            input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
            input type="hidden" name="type" value="Undo"
            input type="hidden" name="object" value=_follow.iri
            input.ui.button type="submit" value="Unfollow"
        - else
          form method="POST" action=outbox_path(_account)
            input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
            input type="hidden" name="type" value="Follow"
            input type="hidden" name="object" value=actor.iri
            input.ui.primary.button type="submit" value="Follow"
