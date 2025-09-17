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
            label Display Name
            input type="text" name="name" value=actor.display_name placeholder="Enter your display name"
          .field
            label Summary
            input type="text" name="summary" value=actor.summary placeholder="Brief bio or description"
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
            input type="text" name="site" value=Ktistec.settings.site placeholder="Enter site name"
          .field
            label Footer
            input type="text" name="footer" value=Ktistec.settings.footer placeholder="Footer text"
          .inline.fields
            label Use Translator Service
            .field
              .ui.radio.checkbox
                input type="radio" name="translator_service" value="deepl"
                label DeepL
            .field
              .ui.radio.checkbox
                input type="radio" name="translator_service" value="libretranslate"
                label LibreTranslate
            .field
              .ui.radio.checkbox
                input type="radio" name="translator_service" value="" checked=""
                label None
          .field
            label Translator Service URL
            input type="text" name="translator_url" placeholder="API endpoint URL"
          p.ui.documentation
            em If you are struggling to get translation to work, enable debug logging for the translator(s)
              a< href="#" here
              | .
          .ui.primary.button Update
      .variation-label Form with Error
      .ui.text.container
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
      .ui.form.editor
        .field
          == trix_editor("Description", Ktistec.settings, description)
