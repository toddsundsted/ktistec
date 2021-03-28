.label
  - if _author != _actor
    - if (icon = _actor.icon)
      img data-actor-id=_actor.id src=icon
    - else
      i.user.icon
  - if (icon = _author.icon)
    img data-actor-id=_author.id src=icon
  - else
    i.user.icon
