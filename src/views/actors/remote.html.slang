== render "src/views/partials/actor-medium.html.slang"
h2 Recent
section.ui.feed
  - activities = actor.public_posts(*pagination_params(env))
  - activities.each do |activity|
    article.event.activity
      - if activity.is_a?(ActivityPub::Activity::Create) || activity.is_a?(ActivityPub::Activity::Announce)
        == render "src/views/partials/activities/create.html.slang"
== paginate(activities, env)
