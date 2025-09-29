- content_for "title" do
  | Admin: Add Account
h1.ui.header Add Account
p Create a new user account. Username and password are required.
p Usernames can be any length and can consist of any combination of letters, numbers, underscores, dashes and periods.
p Passwords must be at least six characters long, and must consist of at least one letter, one number and one symbol.
crystal:
  form_action = "/admin/accounts"
  button_text = "Create User"
== render "src/views/partials/account_form.html.slang"
a.ui.button href="/admin/accounts" Back to Accounts
