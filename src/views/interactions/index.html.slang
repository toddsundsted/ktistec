- content_for "title" do
  | Follow #{actor.display_name}
- if (icon = actor.icon)
  p: img.ui.small.circular.image src=icon
p
  | You can follow #{actor.display_name} from the server where your
    Fediverse account is hosted. Enter the domain name of that server
    below. You can also enter your full Fediverse handle.
form.ui.form class=(error ? "error" : "") method="POST" data-turbo="false"
  == authenticity_token(env)
  - if error
    .ui.error.message
      p= error.capitalize
  .field
    label Your Domain
    input type="text" name="domain" value=domain placeholder="e.g. example.social"
  input.ui.primary.button type="submit" value="Go Home"
