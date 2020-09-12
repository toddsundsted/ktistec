- _actor = activity.object.actor
== render "src/views/partials/activities/label.html.slang"
.content
  .summary
    ' You rejected a follow request from
    a href=_actor.display_link = _actor.display_name
    | .
