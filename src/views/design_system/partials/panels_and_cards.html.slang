#actor-components.design-system-section
  h2 Actor Components
  .component-showcase
    h4 Actor Panel
    .variation-group
      .variation-label Normal Actor Panel
      .ui.text.container
        .ui.actor.segments
          - image = actor.image.presence
          - style = image ? "background-image: url(#{actor.image});" : nil
          .ui.basic.segment class=(!image ? "placeholder" : nil) style=style
            .actor-icon-container
              == actor_icon(actor)
              i.actor-type-overlay.user.icon
          .ui.attached.tiny.warning.icon.message
            i.cloud.icon
            .content
              p
                | Due to failures to deliver posts to this actor, the
                  actor is marked as down. There will be no further
                  delivery attempts.
          .ui.basic.segment
            a href="#" = actor.display_name
            br: a href="#" = actor.handle
            - if (summary = actor.summary.presence)
              br: == s summary
            - if (attachments = actor.attachments.presence)
              .ui.divider
              table
                - attachments.each do |attachment|
                  tr
                    th.name = attachment.name
                    td.value == s wrap_link(attachment.value, length: 50)
          .ui.basic.segment
            details
              summary
                i.orange.clock.outline.icon
                | #{actor.display_name} wants to follow you
              .ui.orange.segment
                .ui.inline.form
                  button.ui.green.button Accept
                .ui.inline.form
                  button.ui.red.button Reject
          .ui.basic.segment
            .ui.inline.form
              button.ui.button Unfollow
            .ui.inline.form
              button.ui.button Refresh
            .information
              | Follow request accepted about 1 month ago
              br
              | Profile refreshed 10 days ago
      .variation-label Blocked Actor Panel
      .ui.text.container
        .ui.actor.segments
          .ui.basic.blocked.segment
            | [blocked]
            br: a href="#" [blocked]
            br: em This actor is blocked!
          .ui.basic.segment
            .ui.inline.form
              button.ui.button Unblock
            .ui.inline.form
              button.ui.button Refresh
            .information
              | Profile refreshed 10 days ago
  .component-showcase
    h4 Actor Card
    .variation-group
      .variation-label Normal Actor Card
      .ui.text.container
        .ui.fluid.actor.card
          - image = actor.image.presence
          - style = image ? "background-image: url(#{actor.image});" : nil
          .content class=(!image ? "placeholder" : nil) style=style
            == actor_icon(actor)
          .extra.content
            a.ui.header href="#" = actor.display_name
            a.ui.link href="#" = actor.handle
          .extra.content
            .ui.inline.form
              .ui.button.primary Follow
            .ui.inline.form
              .ui.button.dangerous Block
      .variation-label Blocked Actor Card
      .ui.text.container
        .ui.fluid.actor.card
          .blocked.content
            em This actor is blocked!
          .extra.content
            .ui.inline.form
              .ui.button Unblock
