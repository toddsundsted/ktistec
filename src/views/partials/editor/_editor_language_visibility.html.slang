- if (language = object.language.presence || env.account.language.presence)
  .inline.fields
    .ten.wide.field
      - partial "partials/visibility_controls"
    .six.wide.field class=(errors["language"]? ? "error" : nil)
      label Language
      input type="text" name="language" value=language
- else
  .inline.fields
    - partial "partials/visibility_controls"
