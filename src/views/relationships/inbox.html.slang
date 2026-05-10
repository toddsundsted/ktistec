- title = env.request.path.split("/").last.titleize
- content_for "title" do
  = title
h1= title
section.ui.feed data-controller="icon-load-error"
  - activities.each do |activity|
    - if activity.is_a?(ActivityPub::Activity::Announce)
      - Slang.embed("src/views/partials/activity/create.html.slang", content_io)
    - elsif activity.is_a?(ActivityPub::Activity::Create)
      - Slang.embed("src/views/partials/activity/create.html.slang", content_io)
    - elsif activity.is_a?(ActivityPub::Activity::Follow)
      - Slang.embed("src/views/partials/activity/follow/inbox.html.slang", content_io)
    - elsif activity.is_a?(ActivityPub::Activity::Accept)
      - Slang.embed("src/views/partials/activity/accept/inbox.html.slang", content_io)
    - elsif activity.is_a?(ActivityPub::Activity::Reject)
      - Slang.embed("src/views/partials/activity/reject/inbox.html.slang", content_io)
    - else
      - Slang.embed("src/views/partials/activity/default.html.slang", content_io)
- paginate(env, activities, content_io)
