turbo-frame#thread_page_thread_controls
  .ui.thread.segments
    .ui.segment
      crystal:
        seed = Hash(ActivityPub::Actor, Int32).new(0)
        contributors = thread.reduce(seed) do |acc, object|
          acc[object.attributed_to] += 1 if object.attributed_to?
          acc
        end
        # boost OP
        op = contributors.first_key
        contributors[op] = Int32::MAX
      p Contributors to this thread:
      p
        - contributors.to_a.sort_by(&.last.-).truncate(0, 18).each do |actor, _|
          a data-turbo-frame="_top" href=remote_actor_path(actor)
            - if (icon = actor.icon)
              img.ui.avatar.image data-actor-id=actor.id src=icon
      - if env.account?
        - if (_task = task) && (_status = fetch_task_status_line(_task, thread))
          p.task
            em = _status
    - if env.account?
      .ui.basic.segment
        - if follow.nil? || follow.new_record?
          == form_button "Follow", follow_thread_path(thread.first), button_class: "ui button primary"
        - else
          == form_button "Unfollow", unfollow_thread_path(thread.first)
section.ui.feed data-controller="icon-load-error"
  - thread.each do |object|
    == object_partial(env, object, for_thread: thread)
