== render "src/views/partials/activity/label.html.slang"
.content
  .summary
    ' You followed
    a href=activity.object.display_link = activity.object.display_name
    | .
  - _response = activity.accepted_or_rejected?
  - if _response.is_a?(ActivityPub::Activity::Accept)
    .extra.meta
      | Accepted on #{ _response.display_date }.
  - elsif _response.is_a?(ActivityPub::Activity::Reject)
    .extra.meta
      | Rejected on #{ _response.display_date }.
