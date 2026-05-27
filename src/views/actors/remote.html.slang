- if !actor.blocked?
  turbo-stream-source src=stream_path("actors", actor.id)
  - partial actor_panel_partial(env, actor)
  section.ui.feed data-controller="icon-load-error"
    - pinned.each do |object|
      - partial object_partial(env, object, for_actor: actor)
    - objects.each do |object|
      - partial object_partial(env, object, for_actor: actor)
  - partial paginate(env, objects)
- else
  - partial actor_panel_partial(env, actor)
