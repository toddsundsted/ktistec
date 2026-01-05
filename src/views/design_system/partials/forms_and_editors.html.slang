#form-components.design-system-section
  h2 Form and Editor Components
  .component-showcase
    h4 Semantic UI Forms
    .variation-group
      .variation-label Standard Form
      .ui.text.container
        h1 Account Settings
        p Settings for account <strong>#{actor.username}</strong>.
        .ui.form
          .field
            label Name
            input type="text" name="name" value=actor.display_name
          .field
            label Summary
            textarea name="summary" rows="3" = actor.summary
          .field
            label Language
            input type="text" name="language" placeholder="IETF BCP 47 language tag. For example: en-US"
          .field
            label Timezone
            input type="text" name="timezone" placeholder="IANA time zone database identifier. For example: America/Chicago"
          .field
            label Password
            input type="password" name="password" placeholder="Leave blank to leave unchanged"
          .field
            label Metadata
            p You can have up to four items displayed on your profile.
          .two.fields
            .field
              label Name
            .field
              label Value
          - if (attachments = actor.attachments.presence)
            - attachments.each_with_index do |attachment, index|
              .two.fields
                .field
                  input type="text" name="attachment_#{index}_name" value=attachment.name placeholder="Field name"
                .field
                  input type="text" name="attachment_#{index}_value" value=attachment.value placeholder="Field value"
          - else
            .two.fields
              .field
                input type="text" name="attachment_0_name" placeholder="Field name"
              .field
                input type="text" name="attachment_0_value" placeholder="Field value"
          .ui.primary.button Update
        h2 Delete Account!
        p Delete account <strong>#{actor.username}</strong>. This action cannot be undone!
        .ui.form
          .ui.dangerous.button Delete Account
        h1 Site Settings
        .ui.form
          .field
            label Site Name
            input type="text" name="site" value=Ktistec.settings.site placeholder="Site name"
          .field
            label Footer
            input type="text" name="footer" value=Ktistec.settings.footer placeholder="Footer text"
          .inline.fields
            label for="translator_service" Use Translator Service
            .field
              .ui.radio.checkbox
                input#ts-deepl type="radio" name="translator_service" value="deepl"
                label for="ts-deepl" DeepL
            .field
              .ui.radio.checkbox
                input#ts-libretranslate type="radio" name="translator_service" value="libretranslate"
                label for="ts-libretranslate" LibreTranslate
            .field
              .ui.radio.checkbox
                input#ts-none type="radio" name="translator_service" value="" checked=""
                label for="ts-none" None
          .field
            label Translator Service URL
            input type="text" name="translator_url" placeholder="API endpoint URL"
          p.ui.documentation
            em If you are struggling to get translation to work, enable debug logging for the translator(s)
              a< href="#" here
              | .
          .ui.primary.button Update
        h1 Chart Options
        .ui.form
          .two.fields
            .field
              label Range
              select.ui.selection.dropdown name="begin"
                option value="2025-09-13" selected="" Last 7 Days
                option value="2025-08-21" Last 30 Days
                option value="2024-09-20" Last 365 Days
                option value="" All Time
            .field
              label Granularity
              select.ui.selection.dropdown name="granularity"
                option value="daily" selected="" By Day
                option value="weekly" By Week
                option value="monthly" By Month
          input.ui.primary.button type="submit" value="Update"
      .variation-label Form with Error
      .ui.text.container
        h1 Account Settings
        .ui.form.error
          .ui.error.message
            .header language is unsupported
          .field.error
            label Language
            input type="text" name="language" value="foo-BAR" placeholder="IETF BCP 47 language tag. For example: en-US"
          .ui.primary.button Submit
  .component-showcase
    h4 Trix Editor
    .ui.text.container
      .ui.form
        .field
          == trix_editor("Description", Ktistec.settings, description)
        .inline.fields
          .ten.wide.field
            label for="visibility" Visibility
            .inline.field
              .ui.radio.checkbox
                input#v-public type="radio" name="visibility" value="public"
                label for="v-public" Everyone
            .inline.field
              .ui.radio.checkbox
                input#v-private type="radio" name="visibility" value="private"
                label for="v-private" Followers
            .inline.field
              .ui.radio.checkbox
                input#v-direct type="radio" name="visibility" value="direct" checked="checked"
                label for="v-direct" Mentions
          .six.wide.field
            label Language
            input type="text" name="language" value="en-US"
        details open="open"
          summary Optional Settings
          .field
            label Title
            input type="text" name="name"
          .field
            label Summary
            textarea name="summary" rows="2"
          .field
            .ui.checkbox
              input#content-warning type="checkbox" name="sensitive"
              label for="content-warning" Content warning
          .field
            label Canonical Path
            input type="text" name="canonical-path"
        .ui.buttons
          input.ui.primary.button.disabled type="submit" value="Publish Post"
          input.ui.button.disabled type="submit" value="Save Draft"
  .component-showcase
    h4 Markdown Editor
    .ui.text.container
      form.ui.form method="POST" action="/design-system"
        .field
          label Markdown Content
          textarea.markdown-editor data-controller="editor--markdown" data-action="input->editor--markdown#input" name="markdown-content" rows="3"
        .field
          label Language
          input type="text" name="language" value="en-US"
        .ui.buttons
          input.ui.primary.button.disabled type="submit" value="Publish Post"
          input.ui.button.disabled type="submit" value="Save Draft"
  .component-showcase
    h4 Tables
    .variation-group
      .variation-label Celled Table
      .ui.text.container
        table.ui.compact.structured.celled.table
          tbody
            tr
              td rowspan=2 Task::Foo
              td The next run is in 1 minute.
            tr
              td All work and no play makes Jack a dull boy.
            tr
              td Task::Bar
              td The next run is in 4 minutes.
      .variation-label Basic Table
      .ui.text.container
        table.ui.basic.table
          tbody
            tr
              th.one.wide Task
              th.four.wide
            tr
              td Task::Foo
              td The last run was 23 hours ago.
            tr
              td Task::Bar
              td The last run was about 1 hour ago.
