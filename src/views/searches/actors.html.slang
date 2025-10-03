h1 Search Results
p Found #{pluralize(actors.size, "actor")} matching "#{query}"
- actors.each do |actor|
  == _view_src_views_partials_actor_panel_html_slang(env, actor)
== render "src/views/searches/form.html.slang"
