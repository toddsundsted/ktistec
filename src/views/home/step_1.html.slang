h1 Specify the Host Name and Site Name
- unless settings.errors.empty?
  - error = settings.errors.flat_map { |k, vs| vs.map { |v| "#{k} #{v}" } }.join(", ")
form.ui.form class=(error ? "error" : "") method="POST"
  - if error
    .ui.error.message
      .header= error
  .field class=(settings.errors["host"]? ? "error" : nil)
    label Host Name
    input type="text" name="host" value=settings.host placeholder="https://[host]/"
  .field class=(settings.errors["site"]? ? "error" : nil)
    label Site Name
    input type="text" name="site" value=settings.site
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input.ui.primary.button type="submit" value="Submit"
