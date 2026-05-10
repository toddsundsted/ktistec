- if !actor.blocked?
  turbo-stream-source src=stream_path("actors", actor.id)
  - partial actor_panel_partial(env, actor)
  - objects = actor.known_posts(**pagination_params(env))
  - partial "actors/known_posts"
- else
  - partial actor_panel_partial(env, actor)
