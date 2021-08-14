== render "src/views/partials/actor-medium.html.slang"
h2 Recent
section.ui.feed
  - posts = actor.known_posts(*pagination_params(env))
  - posts.each do |post|
    == object_partial(env, post)
== paginate(env, posts)
