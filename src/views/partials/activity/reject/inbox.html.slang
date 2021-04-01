article.event
  - _actor = activity.actor
  == render "src/views/partials/activity/label.html.slang"
  .content
    .summary
      a> href=_actor.display_link = _actor.display_name
      | rejected your follow request.
