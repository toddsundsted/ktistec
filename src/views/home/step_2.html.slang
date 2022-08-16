h1 Account Information
p Create the primary account. Username and password are required.
p Usernames can be any length and can consist of any combination of letters, numbers, underscores, dashes and periods.
p Passwords must be at least six characters long, and must consist of at least one letter, one number and one symbol.
== form_tag(account, "/") do
  == error_messages(account)
  == input_tag("Username", account, username)
  == input_tag("Password", account, password, type: "password")
  == input_tag("Display Name", actor, name)
  == input_tag("Summary", actor, summary)
  == input_tag("Timezone", account, timezone, data: {"controller" => "local-timezone"})
  input.ui.primary.button type="submit" value="Sign Up"
p.small.text Ktistec Version #{Ktistec::VERSION}
