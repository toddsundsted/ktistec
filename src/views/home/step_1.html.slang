h1 Specify the Host Name and Site Name
form.ui.form class=(error ? "error" : "") method="POST"
  - if error
    .ui.error.message
      .header= error
  .field
    label Host Name
    input type="text" name="host" value=_host placeholder="https://[host]/"
  .field
    label Site Name
    input type="text" name="site" value=_site
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input.ui.primary.button type="submit" value="Submit"
