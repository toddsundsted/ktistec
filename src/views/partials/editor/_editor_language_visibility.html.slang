- if (language = object.language.presence || env.account.language.presence)
  .inline.fields
    .ten.wide.field
      - Slang.embed("src/views/partials/visibility_controls.html.slang", content_io)
    .six.wide.field class=(errors["language"]? ? "error" : nil)
      label Language
      input type="text" name="language" value=language
- else
  .inline.fields
    - Slang.embed("src/views/partials/visibility_controls.html.slang", content_io)
