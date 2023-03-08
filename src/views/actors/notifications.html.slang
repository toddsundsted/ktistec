- content_for "title" do
  | Notifications
- if notifications.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.exclamation.icon
      | There is nothing here, yet.
    .ui.text
      | This page lists notifications about mentions, replies, follows, etc. that you've received.
- else
  h1 Notifications
  section.ui.feed
    - notifications.each do |notification|
      article.event
        - if notification.is_a?(Relationship::Content::Notification::Announce)
          - activity = notification.activity.as(ActivityPub::Activity::Announce)
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
        - elsif notification.is_a?(Relationship::Content::Notification::Like)
          - activity = notification.activity.as(ActivityPub::Activity::Like)
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
        - elsif notification.is_a?(Relationship::Content::Notification::Reply)
          - activity = notification.activity.as(ActivityPub::Activity::Create)
          .label
            - if (icon = activity.actor.icon)
              img data-actor-id=activity.actor.id src=icon
            - else
              i.user.icon
          .content
            .summary
              a> href=remote_actor_path(activity.actor) = activity.actor.display_name
              a> href=remote_object_path(activity.object) replied to
              a< href=remote_object_path(activity.object.in_reply_to) your post
              | .
        - elsif notification.is_a?(Relationship::Content::Notification::Hashtag)
          - activity = notification.activity.as(ActivityPub::Activity::Create)
          .label
            - if (icon = activity.actor.icon)
              img data-actor-id=activity.actor.id src=icon
            - else
              i.user.icon
          .content
            .summary
              crystal:
                ht1 = activity.object.hashtags.map(&.name)
                ht2 = Relationship::Content::Follow::Hashtag.where(actor: env.account.actor).map(&.name)
                hashtags = (ht1 & ht2) + (ht1 - ht2)
              a> href=remote_actor_path(activity.actor) = activity.actor.display_name
              | tagged
              a<> href=remote_object_path(activity.object) a post
              | with
              - hashtags.each do |hashtag|
                a< href=hashtag_path(hashtag) ##{hashtag}
              | .
        - elsif notification.is_a?(Relationship::Content::Notification::Mention)
          - activity = notification.activity.as(ActivityPub::Activity::Create)
          .label
            - if (icon = activity.actor.icon)
              img data-actor-id=activity.actor.id src=icon
            - else
              i.user.icon
          .content
            .summary
              a> href=remote_actor_path(activity.actor) = activity.actor.display_name
              a<> href=remote_object_path(activity.object) mentioned
              | you.
        - elsif notification.is_a?(Relationship::Content::Notification::Follow)
          - activity = notification.activity.as(ActivityPub::Activity::Follow)
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
        - elsif notification.is_a?(Relationship::Content::Notification::Thread)
          - activity = notification.activity.as(ActivityPub::Activity::Create)
          .label
            - if (icon = activity.actor.icon)
              img data-actor-id=activity.actor.id src=icon
            - else
              i.user.icon
          .content
            .summary
              a> href=remote_actor_path(activity.actor) = activity.actor.display_name
              a<> href=remote_object_path(activity.object) replied to a thread
              | you follow.
        - else
          - activity = notification.activity
          .content
            .meta
              a href=activity.iri
  == paginate(env, notifications)
