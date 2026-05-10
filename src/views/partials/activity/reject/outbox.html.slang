article.event
  - _actor = activity.object.actor
  - Slang.embed("src/views/partials/activity/label.html.slang", content_io)
  .content
    .summary
      ' You rejected a follow request from
      a href=_actor.display_link = _actor.display_name
      | .
