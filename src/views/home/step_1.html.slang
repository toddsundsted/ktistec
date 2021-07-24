h1 Specify the Host Name and Site Name
== form_tag(settings, "/") do
  == authenticity_token(env)
  == error_messages(settings)
  == input_tag("Host Name", settings, host, placeholder: "https://[host]/")
  == input_tag("Site Name", settings, site)
  input.ui.primary.button type="submit" value="Submit"
