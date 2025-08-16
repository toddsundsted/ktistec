.ui.very.padded.center.aligned.basic.segment
  h2.ui.icon.header
    i.shield.alternate.icon
    .content Authorize Application
  p
    | The application <strong>#{client.client_name}</strong> is
      requesting permission to access your account.
  p
    | This application will be granted access to the following:
  .ui.list
    - scope.split.each do |s|
      .item
        i.check.icon
        | #{s.upcase}
  .ui.info.message
    p
      | By approving, you will be redirected back to
        <strong>#{client.client_name}</strong> and granted access to
        this service.
  form.ui.form method="POST" data-turbo="false"
    == authenticity_token(env)
    input type="hidden" name="state" value=state
    input type="hidden" name="client_id" value=client.client_id
    input type="hidden" name="redirect_uri" value=redirect_uri
    input type="hidden" name="response_type" value=response_type
    input type="hidden" name="scope" value=scope
    input type="hidden" name="code_challenge" value=code_challenge
    input type="hidden" name="code_challenge_method" value=code_challenge_method
    button.ui.primary.button type="submit" name="approve" value="1" Approve
    button.ui.button type="submit" name="deny" value="1" Deny
