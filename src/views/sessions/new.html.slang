h1 Sign In
form.ui.form class=(message ? "error" : "") action=sessions_path method="POST"
  == authenticity_token(env)
  - if message
    .ui.error.message
      .header = message
  == input_tag("Username", nil, username)
  == input_tag("Password", nil, password, type: "password")
  == submit_button("Sign In")
p.small.text Ktistec Version #{Ktistec::VERSION}
