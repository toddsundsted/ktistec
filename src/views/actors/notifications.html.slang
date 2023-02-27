- content_for "title" do
  | Notifications
- activities = notifications.map(&.activity)
- if activities.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.exclamation.icon
      | There is nothing here, yet.
    .ui.text
      | This page lists notifications about mentions, replies, follows, etc. that you've received.
- else
  h1 Notifications
  section.ui.feed
    - activities.each do |activity|
      article.event
        - if activity.is_a?(ActivityPub::Activity::Announce)
          .label
            - if (icon = activity.actor.icon)
              img data-actor-id=activity.actor.id src=icon
            - else
              i.user.icon
          .content
            .summary
              a> href=remote_actor_path(activity.actor) = activity.actor.display_name
              | shared
              a< href=remote_object_path(activity.object) your post
              | .
        - elsif activity.is_a?(ActivityPub::Activity::Like)
          .label
            - if (icon = activity.actor.icon)
              img data-actor-id=activity.actor.id src=icon
            - else
              i.user.icon
          .content
            .summary
              a> href=remote_actor_path(activity.actor) = activity.actor.display_name
              | liked
              a< href=remote_object_path(activity.object) your post
              | .
        - elsif activity.is_a?(ActivityPub::Activity::Create)
          .label
            - if (icon = activity.actor.icon)
              img data-actor-id=activity.actor.id src=icon
            - else
              i.user.icon
          .content
            .summary
              - if (in_reply_to = activity.object.in_reply_to?) && in_reply_to.attributed_to? == account.actor
                a> href=remote_actor_path(activity.actor) = activity.actor.display_name
                a> href=remote_object_path(activity.object) replied to
                a< href=remote_object_path(in_reply_to) your post
                | .
              - else
                a> href=remote_actor_path(activity.actor) = activity.actor.display_name
                a<> href=remote_object_path(activity.object) mentioned
                | you.
        - elsif activity.is_a?(ActivityPub::Activity::Follow)
          .label
            - if (icon = activity.actor.icon)
              img data-actor-id=activity.actor.id src=icon
            - else
              i.user.icon
          .content
            .summary
              a> href=remote_actor_path(activity.actor) = activity.actor.display_name
              | followed you.
            - unless (response = activity.accepted_or_rejected?)
              .extra.text
                form.ui.form method="POST" action=outbox_path(account)
                  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
                  input type="hidden" name="object" value=activity.iri
                  input.ui.mini.primary.button type="submit" name="type" value="Accept"
                  input.ui.mini.button type="submit" name="type" value="Reject"
            - if response.is_a?(ActivityPub::Activity::Accept)
              .extra.meta
                | Accepted #{ response.short_date }.
            - elsif response.is_a?(ActivityPub::Activity::Reject)
              .extra.meta
                | Rejected #{ response.short_date }.
        - else
          .content
            .meta
              a href=activity.iri
  == paginate(env, activities)
