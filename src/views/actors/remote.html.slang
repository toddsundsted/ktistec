- if !actor.blocked?
  turbo-stream-source src=stream_path("actors", actor.id)
  - _view_src_views_partials_actor_panel_html_slang(env, actor, content_io)
  - objects = actor.known_posts(**pagination_params(env))
  - Slang.embed("src/views/actors/known_posts.html.slang", content_io)
- else
  - _view_src_views_partials_actor_panel_html_slang(env, actor, content_io)
