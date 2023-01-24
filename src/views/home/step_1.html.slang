h1 Host Name and Site Name
p Specify the host name and the site name for your instance.
== form_tag(settings, "/") do
  == error_messages(settings)
  == input_tag("Host Name", settings, host, placeholder: "ex. https://my.site/")
  == input_tag("Site Name", settings, site, placeholder: "ex. My Site")
  == submit_button
p.small.text Ktistec Version #{Ktistec::VERSION}
