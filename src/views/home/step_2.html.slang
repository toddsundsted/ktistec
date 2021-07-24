h1 Create an Account
== form_tag(account, "/") do
  == authenticity_token(env)
  == error_messages(account)
  == input_tag("Username", account, username, placeholder: "letter, number, underscore, dash, period")
  == input_tag("Password", account, password, type: "password", placeholder: ">= 6 characters; at least one letter, one number, one symbol")
  == input_tag("Display Name", actor, name)
  == input_tag("Summary", actor, summary)
  input.ui.primary.button type="submit" value="Sign Up"
