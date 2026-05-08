h1 Search Results
p Found #{pluralize(actors.size, "actor")} matching "#{query}"
- actors.each do |actor|
  turbo-stream-source src=stream_path("actors", actor.id)
  == _view_src_views_partials_actor_panel_html_slang(env, actor)
- Slang.embed("src/views/searches/form.html.slang", content_io)
