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
      == render "./src/views/partials/follow.html.slang"
