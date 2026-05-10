h1 Search Results
p Found #{pluralize(actors.size, "actor")} matching "#{query}"
- actors.each do |actor|
  turbo-stream-source src=stream_path("actors", actor.id)
  - actor_panel_partial(env, actor, content_io)
- Slang.embed("src/views/searches/form.html.slang", content_io)
