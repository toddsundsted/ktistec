#core-content-components.design-system-section
  h2 Core Content Components
  .component-showcase
    h4 Object Timeline
    .ui.text.container
      section.ui.feed
        .event
          .label
            img src=actor.icon
          .content
            .summary
              a.user> = actor.display_name
              | posted
              a.date just now
            .extra.text
              p Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
            .meta
              a href="#"
                button.ui.mini.iconic.button
                  i.reply.icon
                  | 3 Replies
              form.ui.inline.form
                button.ui.mini.blue.iconic.button
                  i.thumbs.up.icon
                  | 1 Like
              form.ui.inline.form
                button.ui.mini.iconic.button
                  i.share.icon
                  | 1 Share
              form.ui.inline.form
                button.ui.mini.iconic.button
                  i.paper.plane.icon
                  | Translate
              form.ui.inline.form
                button.ui.mini.dangerous.iconic.button
                  i.trash.icon
                  | Delete
        .event
          .label
            img src=actor.icon
            img src=actor.icon
          .content
            .summary
              a.user> = actor.display_name
              | shared a note by
              a.user< = actor.display_name
              a.date 2 hours ago
            .extra.text
              p Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut enim ad minim veniam, quis nostrud exercitation.
            .meta
              a href="#"
                button.ui.mini.iconic.button
                  i.reply.icon
                  | Reply
              form.ui.inline.form
                button.ui.mini.iconic.button
                  i.thumbs.up.icon
                  | Like
              form.ui.inline.form
                button.ui.mini.blue.iconic.button
                  i.share.icon
                  | 1 Share
              form.ui.inline.form
                button.ui.mini.purple.iconic.button
                  i.paper.plane.icon
                  | Clear
              form.ui.inline.form
                button.ui.mini.dangerous.iconic.button
                  i.times.icon
                  | Block
              a.ui.mini.iconic.button.source href="#"
                i.external.arrow.icon
                | Source
        .event
          .label
            img src=actor.icon
          .content
            .summary
              a.user> = actor.display_name
              | posted
              a.date 3 hours ago
            img.ui.extra.attachment.image src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='600' height='600' viewBox='0 0 600 600'%3E%3Crect width='600' height='600' fill='%23f0f0f0'/%3E%3Ctext x='300' y='300' text-anchor='middle' dy='0.3em' font-family='Arial' font-size='24' fill='%23999'%3EImage Placeholder%3C/text%3E%3C/svg%3E" alt="Placeholder"
            .extra.media
              img.ui.attachment.image src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='200' height='200' viewBox='0 0 200 200'%3E%3Crect width='200' height='200' fill='%23ffffff' stroke='%23e0e0e0' stroke-width='2'/%3E%3Ccircle cx='100' cy='100' r='35' fill='%23f8f9fa' stroke='%23007bff' stroke-width='3'/%3E%3Ctext x='100' y='160' text-anchor='middle' font-family='Arial' font-size='11' fill='%23495057'%3ELight Mode%3C/text%3E%3C/svg%3E" alt="Light Mode"
              img.ui.attachment.image src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='200' height='200' viewBox='0 0 200 200'%3E%3Crect width='200' height='200' fill='%23121212' stroke='%23404040' stroke-width='2'/%3E%3Cpolygon points='100,65 130,135 70,135' fill='%23bb86fc' stroke='%23ffffff' stroke-width='2'/%3E%3Ctext x='100' y='165' text-anchor='middle' font-family='Arial' font-size='11' fill='%23e0e0e0'%3EDark Mode%3C/text%3E%3C/svg%3E" alt="Dark Mode"
            .extra.text
              p Ut enim ad minim veniam!
            .meta
              a href="#"
                button.ui.mini.iconic.button
                  i.reply.icon
                  | Reply
              form.ui.inline.form
                button.ui.mini.iconic.button type="submit"
                  i.thumbs.up.icon
                  | Like
              form.ui.inline.form
                button.ui.mini.iconic.button type="submit"
                  i.share.icon
                  | Share
              form.ui.inline.form
                button.ui.mini.dangerous.iconic.button type="submit"
                  i.times.icon
                  | Block
              a.ui.mini.iconic.button.source href="#"
                i.external.arrow.icon
                | Source
  .component-showcase
    h4 Object Detail
    .ui.text.container
      section.ui.feed
        .detailed.event
          .label
            img src=actor.icon
          .content
            .summary
              a.user> = actor.display_name
              | posted
              a.date href="#" 3 days ago
            .extra.text
              p
                | Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua via
                a< href="#" @username
                a< href="#" #hashtag
            .extra.detail
              .ui.labels
                a.ui.small.label href="#" @username
                a.ui.small.label href="#" #hashtag
            .extra.detail
              a href="#"
                img.ui.avatar.image src=actor.icon
                i.share.icon
            .meta
              a href="#"
                button.ui.mini.iconic.button
                  i.comments.icon
                  | Thread
              a href="#"
                button.ui.mini.iconic.button
                  i.reply.icon
                  | Reply
              form.ui.inline.form
                button.ui.mini.iconic.button type="submit"
                  i.thumbs.up.icon
                  | Like
              form.ui.inline.form
                button.ui.mini.iconic.button type="submit"
                  i.share.icon
                  | Share
              form.ui.inline.form
                button.ui.mini.dangerous.iconic.button type="submit"
                  i.times.icon
                  | Block
              a.ui.mini.iconic.button.source href="#"
                i.external.arrow.icon
                | Source
  .component-showcase
    h4 Threaded Posts
    .ui.text.container
      section.ui.feed
        .threaded.event.depth-0
          .label
            img src=actor.icon
          .content
            .summary
              a.user> = actor.display_name
              | posted
              a.date href="#" 2 hours ago
            .extra.text
              p Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
            .meta
              a href="#"
                button.ui.mini.iconic.button
                  i.reply.icon
                  | 2 Replies
              form.ui.inline.form
                button.ui.mini.iconic.button type="submit"
                  i.thumbs.up.icon
                  | Like
              form.ui.inline.form
                button.ui.mini.blue.iconic.button type="submit"
                  i.share.icon
                  | 1 Share
              a href="#"
                button.ui.mini.iconic.button
                  i.edit.icon
                  | Edit
              form.ui.inline.form
                button.ui.mini.dangerous.iconic.button type="submit"
                  i.trash.icon
                  | Delete
        .threaded.event.depth-1
          .label
            img src=actor.icon
          .content
            .summary
              a.user> = actor.display_name
              | posted
              a.date href="#" 1 hour ago
            .extra.text
              p Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
            .meta
              a href="#"
                button.ui.mini.iconic.button
                  i.reply.icon
                  | 1 Reply
              form.ui.inline.form
                button.ui.mini.blue.iconic.button type="submit"
                  i.thumbs.up.icon
                  | 1 Like
              form.ui.inline.form
                button.ui.mini.iconic.button type="submit"
                  i.share.icon
                  | Share
              form.ui.form
                .ui.mini.toggle.checkbox
                  input#public-1 type="checkbox" name="public" checked="checked"
                  label for="public-1" Public
              a.ui.mini.iconic.button.source href="#" target="_blank"
                i.external.arrow.icon
                | Source
        .threaded.event.depth-2
          .label
            img src=actor.icon
          .content
            .summary
              a.user> = actor.display_name
              | posted
              a.date href="#" 45 minutes ago
            .extra.text
              p Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
            .meta
              a href="#"
                button.ui.mini.iconic.button
                  i.reply.icon
                  | Reply
              form.ui.inline.form
                button.ui.mini.iconic.button type="submit"
                  i.thumbs.up.icon
                  | 2 Likes
              form.ui.inline.form
                button.ui.mini.iconic.button type="submit"
                  i.share.icon
                  | Share
              form.ui.form
                .ui.mini.toggle.checkbox
                  input#public-2 type="checkbox" name="public"
                  label for="public-2" Public
              a href="#"
                button.ui.mini.iconic.button
                  i.edit.icon
                  | Edit
              form.ui.inline.form
                button.ui.mini.dangerous.iconic.button type="submit"
                  i.trash.icon
                  | Delete
  .component-showcase
    h4 Content Variations
    .ui.text.container
      section.ui.feed
        .event.blocked
          .label
            i.user.outline.icon
          .content
            .summary
              a.user> href="#" [blocked]
              | posted
              a.date href="#" 4 days ago
            .extra.text
              em This actor is blocked!
            .meta
              a.ui.mini.iconic.button.source href="#" target="_blank"
                i.external.arrow.icon
                | Source
        .event.deleted
          .label
            i.user.icon
          .content
            .summary
              a.user> href="#" Deleted User
              | posted
              a.date href="#" 5 days ago
            .extra.text.deleted
              p Lorem ipsum dolor sit amet
            .extra.text
              em This content is deleted!
            .meta
              a.ui.mini.iconic.button.source href="#" target="_blank"
                i.external.arrow.icon
                | Source
