== render "src/views/partials/actor-medium.html.slang"
h2 Recent
section.ui.feed
  - posts = actor.public_posts(*pagination_params(env))
  - posts.each do |post|
    == object_partial(env, post)
== paginate(posts, env)
