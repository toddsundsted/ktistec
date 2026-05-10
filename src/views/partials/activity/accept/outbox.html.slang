article.event
  - _actor = activity.object.actor
  - Slang.embed("src/views/partials/activity/label.html.slang", content_io)
  .content
    .summary
      ' You accepted a follow request from
      a href=_actor.display_link = _actor.display_name
      | .
