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
  input type="hidden" name="public" value="true"
  .field
    input#input-trix-editor type="hidden" name="content" value=content
    trix-editor data-controller="trix" data-action="trix-attachment-add@window->trix#add trix-attachment-remove@window->trix#remove trix-change@window->trix#change input->has-content#change" data-has-content-target="input" input="input-trix-editor"
  details open=(object.name || object.summary || object.canonical_path ? true : false)
    summary Optional Settings
    .field
      label Title
      input type="text" name="name" value=object.name
    .field
      label Summary
      textarea name="summary" rows="2" = object.summary
    .field class=(canonical_path_errors ? "error" : nil)
      label Canonical Path
      input type="text" name="canonical_path" value=object.canonical_path
  - if object.new_record? || object.draft?
    .ui.buttons
      input.ui.disabled.primary.button data-has-content-target="button" type="submit" value="Publish Post" formaction=outbox_path(actor)
      - if object.new_record?
        input.ui.disabled.button data-has-content-target="button" type="submit" value="Save Draft" formaction=objects_path
      - else
        input.ui.disabled.button data-has-content-target="button" type="submit" value="Save Draft" formaction=object_path(object)
    - unless object.new_record?
      a.ui.teal.right.floated.button href=actor_relationships_path(actor, "drafts")
        | To Drafts
  - else
    input.ui.disabled.primary.button data-has-content-target="button" type="submit" value="Update Post" formaction=outbox_path(actor)
