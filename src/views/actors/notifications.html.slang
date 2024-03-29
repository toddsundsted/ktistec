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
  section.ui.feed data-controller="icon-load-error"
    - notifications.each do |notification|
      article.event
        - case notification
        - in Relationship::Content::Notification::Announce
          crystal:
            activity = notification.activity
            activities = activity.object.activities(inclusion: activity.type)
          .label
            - if (icon = activity.actor.icon)
              img data-actor-id=activity.actor.id src=icon
            - else
              i.user.icon
          .content
            .summary
              a> href=remote_actor_path(activity.actor) = activity.actor.display_name
              - if activities.size > 1
                | and #{pluralize(activities.size - 1, "other")} shared
              - else
                | shared
              a< href=remote_object_path(activity.object) your post
              | .
            - if (content = Ktistec::Util.render_as_text(activity.object.content).presence)
              .extra.meta.truncated
                == content
        - in Relationship::Content::Notification::Like
          crystal:
            activity = notification.activity
            activities = activity.object.activities(inclusion: activity.type)
          .label
            - if (icon = activity.actor.icon)
              img data-actor-id=activity.actor.id src=icon
            - else
              i.user.icon
          .content
            .summary
              a> href=remote_actor_path(activity.actor) = activity.actor.display_name
              - if activities.size > 1
                | and #{pluralize(activities.size - 1, "other")} liked
              - else
                | liked
              a< href=remote_object_path(activity.object) your post
              | .
            - if (content = Ktistec::Util.render_as_text(activity.object.content).presence)
              .extra.meta.truncated
                == content
        - in Relationship::Content::Notification::Reply
          crystal:
            object = notification.object
            content = Ktistec::Util.render_as_text(object.content).presence
            attributed_to = object.attributed_to
            in_reply_to = object.in_reply_to
          .label
            - if (icon = attributed_to.icon)
              img data-actor-id=attributed_to.id src=icon
            - else
              i.user.icon
          .content
            .summary
              a> href=remote_actor_path(attributed_to) = attributed_to.display_name
              a> href=remote_object_path(object) replied to
              a< href=remote_object_path(in_reply_to) your post
              | .
            - if content
              .extra.meta.truncated
                == content
        - in Relationship::Content::Notification::Mention
          crystal:
            object = notification.object
            content = Ktistec::Util.render_as_text(object.content).presence
            attributed_to = object.attributed_to
          .label
            - if (icon = attributed_to.icon)
              img data-actor-id=attributed_to.id src=icon
            - else
              i.user.icon
          .content
            .summary
              a> href=remote_actor_path(attributed_to) = attributed_to.display_name
              a> href=remote_object_path(object) mentioned
              | you.
            - if content
              .extra.meta.truncated
                == content
        - in Relationship::Content::Notification::Follow::Hashtag
          crystal:
            name = notification.name
            object = Tag::Hashtag.most_recent_object(name)
            content = object ? Ktistec::Util.render_as_text(object.content).presence : nil
            attributed_to = object.try(&.attributed_to)
          .label
            - if attributed_to && (icon = attributed_to.icon)
              img data-actor-id=attributed_to.id src=icon
            - else
              i.user.icon
          .content
            .summary
              | There are new posts tagged with
              a< href=hashtag_path(name) ##{name}
              | .
            - if content
              .extra.meta.truncated
                == content
        - in Relationship::Content::Notification::Follow::Mention
          crystal:
            name = notification.name
            object = Tag::Mention.most_recent_object(name)
            content = object ? Ktistec::Util.render_as_text(object.content).presence : nil
            attributed_to = object.try(&.attributed_to)
          .label
            - if attributed_to && (icon = attributed_to.icon)
              img data-actor-id=attributed_to.id src=icon
            - else
              i.user.icon
          .content
            .summary
              | There are new posts that mention
              a< href=mention_path(name) @#{name}
              | .
            - if content
              .extra.meta.truncated
                == content
        - in Relationship::Content::Notification::Follow
          - activity = notification.activity
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
        - in Relationship::Content::Notification::Follow::Thread
          crystal:
            object = notification.object
            content = Ktistec::Util.render_as_text(object.content).presence
            attributed_to = object.attributed_to
          .label
            - if (icon = attributed_to.icon)
              img data-actor-id=attributed_to.id src=icon
            - else
              i.user.icon
          .content
            .summary
              - if object.iri == object.thread
                | There are replies to
                a<> href=remote_thread_path(object) a thread
                | you follow.
              - else
                a> href=remote_actor_path(attributed_to) = attributed_to.display_name
                a> href=remote_object_path(object) replied to a thread
                | you follow.
            - if content
              .extra.meta.truncated
                == content
        - in Relationship::Content::Notification
          / This can't happen!
  == paginate(env, notifications)
