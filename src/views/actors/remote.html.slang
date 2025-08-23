- if !actor.blocked?
  turbo-stream-source src="/stream/actors/#{actor.id}"
  == _view_src_views_partials_actor_panel_html_slang(env, actor)
  - objects = actor.known_posts(**pagination_params(env))
  == render "src/views/actors/known_posts.html.slang"
- else
  == _view_src_views_partials_actor_panel_html_slang(env, actor)
