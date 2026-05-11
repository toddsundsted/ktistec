article.event
  - _actor = activity.object.actor
  - partial "partials/activity/label"
  .content
    .summary
      ' You rejected a follow request from
      a href=_actor.display_link = _actor.display_name
      | .
