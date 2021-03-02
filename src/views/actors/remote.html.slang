== render "src/views/partials/actor-medium.html.slang"
h2 Recent
section.ui.feed
  - posts = actor.public_posts(*pagination_params(env))
  - posts.each do |post|
    article.event
      - _actor = post.attributed_to
      - _author = post.attributed_to
      - _object = post
      == render "src/views/partials/object.html.slang"
== paginate(posts, env)
