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
          - if (icon = actor.icon)
            a.ui.avatar.image data-turbo-frame="_top" href=remote_actor_path(actor)
              img data-actor-id=actor.id src=icon
      - if env.account?
        - if task && (status = fetch_task_status_line(task, thread))
          p.task
            em = status
    - if env.account?
      .ui.basic.segment
        - if follow.nil? || follow.new_record?
          == form_button "Follow", follow_thread_path(thread.first), button_class: "ui button primary"
        - else
          == form_button "Unfollow", unfollow_thread_path(thread.first)
