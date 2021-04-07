- actor = env.account.actor
form.ui.form id="object-#{object.id}" data-controller="has-content multi-action" data-action="submit->multi-action#squelch" method="POST"
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input type="hidden" name="type" value="Publish"
  input type="hidden" name="object" value=object.iri
  input type="hidden" name="public" value="true"
  .field
    - content = object.source.try(&.content) || object.content || ""
    input#input-trix-editor type="hidden" name="content" value=content
    trix-editor data-controller="trix" data-action="trix-attachment-add@window->trix#add trix-attachment-remove@window->trix#remove trix-change@window->trix#change input->has-content#change" data-has-content-target="input" input="input-trix-editor"
  - if object.draft?
    .ui.buttons
      input.ui.disabled.primary.button data-has-content-target="button" data-action="click->multi-action#submit" type="submit" value="Publish Post" action=outbox_path(actor)
      input.ui.disabled.button data-has-content-target="button" data-action="click->multi-action#submit" type="submit" value="Save Draft" action=object_path(object)
    a.ui.teal.right.floated.button href=actor_relationships_path(actor, "drafts")
      | Back to Drafts
  - else
    input.ui.disabled.primary.button data-has-content-target="button" data-action="click->multi-action#submit" type="submit" value="Update Post" action=outbox_path(actor)
