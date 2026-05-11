article.event
  - _actor = activity.actor
  - partial "partials/activity/label"
  .content
    .summary
      a> href=_actor.display_link = _actor.display_name
      | accepted your follow request.
