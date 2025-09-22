crystal:
  id = object.id || "new"
  has_errors = !object.errors.empty?
  canonical_path_errors = object.errors["canonical_path.from_iri"]?
  must_be_absolute = canonical_path_errors.try(&.includes?("must be absolute"))
  must_not_route = canonical_path_errors.try(&.includes?("must not match an existing route"))
  must_be_unique = canonical_path_errors.try(&.includes?("must be unique"))
  content = object.source.try(&.content) || object.content || ""
  actor = env.account.actor
form.ui.form id="object-#{id}" class=(has_errors ? "error" : nil) data-controller="has-content" method="POST"
  - if canonical_path_errors
    .ui.error.message
      .header The Canonical Path is Invalid
      - if must_be_absolute
        p It must be an absolute path. It must not be a full URL and must not be relative.
      - elsif must_not_route
        p It must not match a path the application already uses.
      - elsif must_be_unique
        p It must not match a path another post already uses.
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input type="hidden" name="type" value="Publish"
  - unless object.new_record?
    input type="hidden" name="object" value=object.iri
  - if object.in_reply_to?
    input type="hidden" name="in-reply-to" value=object.in_reply_to_iri
  .field data-turbo-permanent=true
    trix-editor data-controller="trix" data-action="trix-attachment-add->trix#add trix-attachment-remove->trix#remove trix-change->trix#change trix-change->has-content#check turbo:morph@document->has-content#check" input="editor-input"
    textarea#editor-input data-has-content-target="input" name="content" rows=3 = content
  - if (language = object.language.presence || env.account.language.presence)
    .inline.fields
      .ten.wide.field
        == render "src/views/partials/visibility_controls.html.slang"
      .six.wide.field
        label Language
        input type="text" name="language" value=language
  - else
    .inline.fields
      == render "src/views/partials/visibility_controls.html.slang"
  details open=(object.name || object.summary || object.canonical_path ? true : false)
    summary Optional Settings
    .field
      label Title
      input type="text" name="name" value=object.name
    .field
      label Summary
      textarea name="summary" rows="2" = object.summary
    .field
      .ui.checkbox
        input#content-warning type="checkbox" name="sensitive" value="true" checked=object.sensitive
        label for="content-warning" Content warning
    .field class=(canonical_path_errors ? "error" : nil)
      label Canonical Path
      input type="text" name="canonical_path" value=object.canonical_path
  - if object.new_record? || object.draft?
    .ui.buttons
      input.ui.primary.button data-has-content-target="button" type="submit" value="Publish Post" formaction=outbox_path(actor)
      - if object.new_record?
        input.ui.button data-has-content-target="button" type="submit" value="Save Draft" formaction=objects_path
      - else
        input.ui.button data-has-content-target="button" type="submit" value="Save Draft" formaction=object_path(object)
    - unless object.new_record?
      a.ui.teal.right.floated.button href=actor_relationships_path(actor, "drafts")
        | To Drafts
  - else
    input.ui.primary.button data-has-content-target="button" type="submit" value="Update Post" formaction=outbox_path(actor)
