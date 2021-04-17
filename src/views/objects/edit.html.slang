crystal:
  actor = env.account.actor
  has_errors = !object.errors.empty?
  canonical_path_errors = object.errors["canonical_path.from_iri"]?
  must_be_absolute = canonical_path_errors.try(&.includes?("must be absolute"))
  must_not_route = canonical_path_errors.try(&.includes?("must not match an existing route"))
  must_be_unique = canonical_path_errors.try(&.includes?("must be unique"))
h1 Edit Post
form.ui.form id="object-#{object.id}" class=(has_errors ? "error" : nil) data-controller="has-content multi-action" data-action="submit->multi-action#squelch" method="POST"
  - if canonical_path_errors
    .ui.error.message
      .header The Canonical Path is Invalid!
      - if must_be_absolute
        p It must be an absolute path.
      - elsif must_not_route
        p It must not match an application path.
      - elsif must_be_unique
        p It must be unique.
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input type="hidden" name="type" value="Publish"
  input type="hidden" name="object" value=object.iri
  input type="hidden" name="public" value="true"
  .field
    - content = object.source.try(&.content) || object.content || ""
    input#input-trix-editor type="hidden" name="content" value=content
    trix-editor data-controller="trix" data-action="trix-attachment-add@window->trix#add trix-attachment-remove@window->trix#remove trix-change@window->trix#change input->has-content#change" data-has-content-target="input" input="input-trix-editor"
  .field class=(canonical_path_errors ? "error" : nil)
    label Canonical Path
    input type="text" name="canonical_path" value=object.canonical_path
  - if object.draft?
    .ui.buttons
      input.ui.disabled.primary.button data-has-content-target="button" data-action="click->multi-action#submit" type="submit" value="Publish Post" action=outbox_path(actor)
      input.ui.disabled.button data-has-content-target="button" data-action="click->multi-action#submit" type="submit" value="Save Draft" action=object_path(object)
    a.ui.teal.right.floated.button href=actor_relationships_path(actor, "drafts")
      | Back to Drafts
  - else
    input.ui.disabled.primary.button data-has-content-target="button" data-action="click->multi-action#submit" type="submit" value="Update Post" action=outbox_path(actor)
