h1 Settings
form.ui.form method="POST"
  .field
    label Display Name
    input type="text" name="name" value=actor.name placeholder="Display Name"
  .field
    label Summary
    input type="text" name="summary" value=actor.summary placeholder="Summary"
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input.ui.primary.button type="submit" value="Update"
