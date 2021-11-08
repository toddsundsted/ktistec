- if !actor.blocked?
  == render "src/views/partials/actor-panel.html.slang"
  - objects = actor.known_posts(*pagination_params(env))
  == render "src/views/actors/known_posts.html.slang"
- else
  == render "src/views/partials/actor-panel.html.slang"
