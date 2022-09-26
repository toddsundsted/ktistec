h1= actor.display_name
- if (icon = actor.icon)
  p: img.ui.small.image src=icon
- if (summary = actor.summary)
  p == s summary
form.ui.form class=(error ? "error" : "") method="POST" data-turbo="false"
  - if error
    .ui.error.message
      p= error.capitalize
  .field
    label Your Address
    p This should be the address of your unique identity in the fediverse.
    input type="text" name="account" value=account placeholder="username@domain.domain"
  input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
  input.ui.primary.button type="submit" value="Submit"
