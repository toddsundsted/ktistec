== render "src/views/partials/actor-large.html.slang"
h1 Settings
form.ui.form method="POST" action="/settings"
  .field
    label Display Name
    input type="text" name="name" value=actor.name
  .field
    label Summary
    input type="text" name="summary" value=actor.summary
  .field
    label Background Image
    input.filepond type="file" name="image"
  .field
    label Profile Image
    input.filepond type="file" name="icon"
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input.ui.primary.button type="submit" value="Update"
h2 Dangerous
form.ui.form method="POST" action="/settings/terminate"
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input.ui.dangerous.button type="submit" value="Delete Account" data-modal="terminate"
.ui.basic.tiny.terminate.modal
  .header: i.trash.icon
    | Delete This Account
  .content
    p
      | This action will delete this account and all its posts on this
        instance and on all federated instances, and it <strong>cannot
        be undone</strong>. Are you certain you want to delete this
        account?
  .actions
    .ui.red.basic.cancel.inverted.button
      i.remove.icon
      | No
    .ui.green.ok.inverted.button
      i.checkmark.icon
      | Yes
