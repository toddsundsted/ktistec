.ui.segment
  crystal:
    seed = Hash(ActivityPub::Actor, Int32).new(0)
    contributors = thread.reduce(seed) do |acc, obj|
      acc[obj.attributed_to] += 1 if obj.attributed_to?
      acc
    end
    # boost branch root author
    root_author = thread.first.attributed_to
    contributors[root_author] = Int32::MAX
    # remove blocked and deleted actors
    contributors.reject! { |actor, _| actor.blocked? || actor.deleted? }
  p Contributors to this branch:
  p
    - contributors.to_a.sort_by(&.last.-).truncate(0, 18).each do |actor, _|
      a.ui.avatar.image data-turbo-frame="_top" href=remote_actor_path(actor)
        == actor_icon(actor)
  p style="margin-top: 10px;"
    - if (parent = object.in_reply_to?) && parent.in_reply_to?
      a.ui.button href=remote_branch_path(parent)
        i.arrow.up.icon
        | Parent
    - elsif parent
      a.ui.button href=remote_thread_path(parent)
        i.arrow.up.icon
        | Thread
section.ui.feed data-controller="icon-load-error"
  - thread.each do |object|
    == object_partial(env, object, for_thread: thread)
