- _actor = activity.actor
- _object = activity.object
== render "src/views/partials/activity/label.html.slang"
.content
  .summary
    ' You received a follow request from
    a href=_actor.display_link = _actor.display_name
    | .
  - unless (_response = activity.accepted_or_rejected?)
    .extra.text
      form.ui.form method="POST" action=actor_relationships_path(account, "outbox")
        input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
        input type="hidden" name="object" value=activity.iri
        input.ui.mini.primary.button type="submit" name="type" value="Accept"
        input.ui.mini.button type="submit" name="type" value="Reject"
  - if _response.is_a?(ActivityPub::Activity::Accept)
    .extra.meta
      | Accepted on #{ _response.display_date }.
  - elsif _response.is_a?(ActivityPub::Activity::Reject)
    .extra.meta
      | Rejected on #{ _response.display_date }.
