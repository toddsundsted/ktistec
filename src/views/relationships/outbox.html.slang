- title = env.request.path.split("/").last.titleize
- content_for "title" do
  = title
h1= title
section.ui.feed data-controller="icon-load-error"
  - activities.each do |activity|
    - if activity.is_a?(ActivityPub::Activity::Announce)
      - partial "partials/activity/create"
    - elsif activity.is_a?(ActivityPub::Activity::Create)
      - partial "partials/activity/create"
    - elsif activity.is_a?(ActivityPub::Activity::Follow)
      - partial "partials/activity/follow/outbox"
    - elsif activity.is_a?(ActivityPub::Activity::Accept)
      - partial "partials/activity/accept/outbox"
    - elsif activity.is_a?(ActivityPub::Activity::Reject)
      - partial "partials/activity/reject/outbox"
    - else
      - partial "partials/activity/default"
- partial paginate(env, activities)
