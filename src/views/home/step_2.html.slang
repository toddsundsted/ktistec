h1 Account Information
p Create the primary account. Username and password are required.
p Usernames can be any length and can consist of any combination of letters, numbers, underscores, dashes and periods.
p Passwords must be at least six characters long, and must consist of at least one letter, one number and one symbol.
crystal:
  form_action = "/"
  button_text = "Submit"
== render "src/views/partials/account_form.html.slang"
p.small.text Ktistec Version #{Ktistec::VERSION}
