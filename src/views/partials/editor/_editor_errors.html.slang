- if canonical_path_errors
  .ui.error.message
    .header The Canonical Path is Invalid
    - if must_be_absolute
      p It must be an absolute path. It must not be a full URL and must not be relative.
    - elsif must_not_route
      p It must not match a path the application already uses.
    - elsif must_be_unique
      p It must not match a path another post already uses.
