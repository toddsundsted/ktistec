h1 Search Results
p Found #{pluralize(actors.size, "actor")} matching "#{query}"
- actors.each do |actor|
  turbo-stream-source src=stream_path("actors", actor.id)
  - partial actor_panel_partial(env, actor)
- partial "searches/form"
