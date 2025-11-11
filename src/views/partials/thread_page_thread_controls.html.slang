crystal:
  _task = task
  _follow = follow
turbo-frame#thread_page_thread_controls
  .ui.thread.segments
    .ui.segment
      turbo-frame#thread_analysis
        crystal:
          seed = Hash(ActivityPub::Actor, Int32).new(0)
          contributors = thread.reduce(seed) do |acc, object|
            acc[object.attributed_to] += 1 if object.attributed_to?
            acc
          end
          # boost OP
          op = contributors.first_key
          contributors[op] = Int32::MAX
          # remove blocked and deleted actors
          contributors.reject! { |actor, _| actor.blocked? || actor.deleted? }
        p: strong Contributors to this thread
          - unless thread.size < 10 || (_task && _task.running)
            a< href=remote_thread_analysis_path(thread.first) data-turbo-frame="thread_analysis" (full analysis)
        p
          - contributors.to_a.sort_by(&.last.-).truncate(0, 18).each do |actor, _|
            - if (icon = actor.icon)
              a.ui.avatar.image data-turbo-frame="_top" href=remote_actor_path(actor)
                img data-actor-id=actor.id src=icon
        - if env.account?
          - if _task && (_status = fetch_task_status_line(_task, thread))
            p.task
              em = _status
    - if env.account?
      .ui.basic.segment
        - if _follow && !_follow.destroyed?
          == form_button "Unfollow", unfollow_thread_path(thread.first)
        - elsif _task && !_task.complete
          == form_button "Cancel", cancel_fetch_thread_path(thread.first)
        - else
          form.ui.inline.form method="POST"
            == authenticity_token(env)
            .ui.buttons
              button.ui.primary.button type="submit" formaction=follow_thread_path(thread.first) Follow
              button.ui.button type="submit" formaction=start_fetch_thread_path(thread.first) Fetch Once
