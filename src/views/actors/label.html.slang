- content_for "title" do
  | §#{name}
.ui.thread.segments
  .ui.basic.segment
    p: strong
      a href=actor_label_path(actor, name) §#{name}
      span< = pluralize(count, "label")
section.ui.feed data-controller="icon-load-error"
  - objects.each do |object|
    - partial object_partial(env, object)
- partial paginate(env, objects)
