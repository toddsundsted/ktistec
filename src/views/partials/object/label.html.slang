.label
  - if author != actor
    - if actor.deleted?
      i.user.outline.icon
    - elsif actor.blocked?
      i.user.outline.icon
    - elsif (icon = actor.icon)
      img data-actor-id=actor.id src=icon
    - else
      i.user.icon
  - if author.deleted?
    i.user.outline.icon
  - elsif author.blocked?
    i.user.outline.icon
  - elsif (icon = author.icon)
    img data-actor-id=author.id src=icon
  - else
    i.user.icon
