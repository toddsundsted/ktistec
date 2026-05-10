- if !actor.blocked?
  turbo-stream-source src=stream_path("actors", actor.id)
  - actor_panel_partial(env, actor, content_io)
  - objects = actor.known_posts(**pagination_params(env))
  - Slang.embed("src/views/actors/known_posts.html.slang", content_io)
- else
  - actor_panel_partial(env, actor, content_io)
