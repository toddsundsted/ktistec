h1= env.params.url["relationship"].titleize
section.ui.cards
  - related.each do |actor|
    == render "src/views/partials/actor-small.html.slang"
== paginate(env, related)
