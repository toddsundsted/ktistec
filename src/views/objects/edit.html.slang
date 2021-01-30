- actor = env.account.actor
form.ui.form id="object-#{object.id}" method="POST"
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input type="hidden" name="type" value="Create"
  input type="hidden" name="public" value="true"
  .field
    - content = object.source.try(&.content) || object.content || ""
    input#input-trix-editor type="hidden" name="content" value=content
    trix-editor input="input-trix-editor"
  .ui.buttons
    input.ui.disabled.primary.button type="submit" value="Post Status" action=outbox_path(actor)
    input.ui.disabled.button type="submit" value="Save Draft" action=object_path(object)
