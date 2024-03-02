- content_for "title" do
  | Follow #{actor.display_name}
- if (icon = actor.icon)
  p: img.ui.small.circular.image src=icon
p You can follow #{actor.display_name} two ways:
ol
  li
    | Navigate back to <em>your server</em> and search for
      <strong>#{actor.handle}</strong> there. You should
      be able to find #{actor.display_name}'s profile and
      follow them.
  li
    | Enter <strong>your address</strong> below and click
      Submit. If both servers support Remote Follow, the
      navigating and searching will happen automatically. You
      will need to follow them.
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
