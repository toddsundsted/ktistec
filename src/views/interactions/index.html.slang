crystal:
  headline = message[0].upcase + message[1..-1] unless message.blank?
- content_for "title" do
  = headline
h1 = headline
p
  | You can #{message} from the server where your
    Fediverse account is hosted. Enter the domain name of that server
    below. You can also enter your full Fediverse handle.
form.ui.form class=(error ? "error" : "") method="POST" action=remote_interaction_path data-turbo="false"
  == authenticity_token(env)
  input type="hidden" name="target" value=target
  input type="hidden" name="action" value=action
  - if error
    .ui.error.message
      p= error.capitalize
  .field
    label Your Domain
    input type="text" name="domain" value=domain placeholder="e.g. example.social"
  input.ui.primary.button type="submit" value="Go Home"
