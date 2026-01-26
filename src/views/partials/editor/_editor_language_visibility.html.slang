- if (language = object.language.presence || env.account.language.presence)
  .inline.fields
    .ten.wide.field
      == render "src/views/partials/visibility_controls.html.slang"
    .six.wide.field class=(errors["language"]? ? "error" : nil)
      label Language
      input type="text" name="language" value=language
- else
  .inline.fields
    == render "src/views/partials/visibility_controls.html.slang"
