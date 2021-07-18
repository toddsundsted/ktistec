h1 Create an Account
- unless account.errors.empty? && actor.errors.empty?
  - error = account.errors.merge(actor.errors).flat_map { |k, vs| vs.map { |v| "#{k} #{v}" } }.join(", ")
form.ui.form class=(error ? "error" : "") method="POST"
  - if error
    .ui.error.message
      .header= error
  .field
    label Username
    input type="text" name="username" value=account.username placeholder="letter, number, underscore, dash, period"
  .field
    label Password
    input type="password" name="password" value=account.password placeholder=">= 6 characters; at least one letter, one number, one symbol"
  .field
    label Display Name
    input type="text" name="name" value=actor.name placeholder="Display Name"
  .field
    label Summary
    input type="text" name="summary" value=actor.summary placeholder="Summary"
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input.ui.primary.button type="submit" value="Sign Up"
