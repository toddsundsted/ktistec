.label
  - if author != actor
    - if (icon = actor.icon)
      img data-actor-id=actor.id src=icon
    - else
      i.user.icon
  - if (icon = author.icon)
    img data-actor-id=author.id src=icon
  - else
    i.user.icon
