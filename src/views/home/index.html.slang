h1 Community
section.ui.cards
  - accounts.map(&.actor).each do |actor|
    == render "src/views/partials/actor-small.html.slang"
h1 Activity
== render "src/views/actors/timeline.html.slang"
