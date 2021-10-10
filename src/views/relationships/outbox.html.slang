- title = env.request.path.split("/").last.titleize
- content_for "title" do
  = title
h1= title
section.ui.feed
  - activities.each do |activity|
    - if activity.is_a?(ActivityPub::Activity::Announce)
      == render "src/views/partials/activity/create.html.slang"
    - elsif activity.is_a?(ActivityPub::Activity::Create)
      == render "src/views/partials/activity/create.html.slang"
    - elsif activity.is_a?(ActivityPub::Activity::Follow)
      == render "src/views/partials/activity/follow/outbox.html.slang"
    - elsif activity.is_a?(ActivityPub::Activity::Accept)
      == render "src/views/partials/activity/accept/outbox.html.slang"
    - elsif activity.is_a?(ActivityPub::Activity::Reject)
      == render "src/views/partials/activity/reject/outbox.html.slang"
    - else
      == render "src/views/partials/activity/default.html.slang"
== paginate(env, activities)
