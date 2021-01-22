- actor = env.account.actor
form.ui.form id="object-#{object.id}" method="POST" action=outbox_path(actor)
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input type="hidden" name="type" value="Create"
  input type="hidden" name="public" value="true"
  .field
    input#input-trix-editor type="hidden" name="content" value=object.content
    trix-editor input="input-trix-editor"
  .ui.buttons
    input.ui.disabled.primary.button type="submit" value="Post Status"
