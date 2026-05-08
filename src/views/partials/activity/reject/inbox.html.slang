article.event
  - _actor = activity.actor
  - Slang.embed("src/views/partials/activity/label.html.slang", content_io)
  .content
    .summary
      a> href=_actor.display_link = _actor.display_name
      | rejected your follow request.
