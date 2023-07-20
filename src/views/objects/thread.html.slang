.ui.thread.segments
  .ui.segment
    p Contributors to this thread:
    crystal:
      seed = Hash(ActivityPub::Actor, Int32).new(0)
      contributors = thread.reduce(seed) do |acc, object|
        acc[object.attributed_to] += 1 if object.attributed_to?
        acc
      end
      # boost OP
      op = contributors.first_key
      contributors[op] = Int32::MAX
    - contributors.to_a.sort_by(&.last.-).truncate(0, 18).each do |actor, _|
        a data-turbo-frame="_top" href=remote_actor_path(actor)
          - if (icon = actor.icon)
            img.ui.avatar.image data-actor-id=actor.id src=icon
  turbo-frame#thread_page_thread_controls
    .ui.basic.segment
      - if follow.nil? || follow.new_record?
        == form_button "Follow", follow_thread_path(thread.first), button_class: "ui button primary"
      - else
        == form_button "Unfollow", unfollow_thread_path(thread.first)
section.ui.feed
  - if env.account? && (iri = thread.first.in_reply_to_iri.presence)
    - message = nil
    == render "#{__DIR__}/partials/fetch.html.slang"
  - thread.each do |object|
    == object_partial(env, object, for_thread: thread)
