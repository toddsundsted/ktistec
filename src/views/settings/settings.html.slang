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
