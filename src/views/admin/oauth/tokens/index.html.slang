- content_for "title" do
  | OAuth Tokens

h1.ui.header OAuth Tokens

table.ui.table
  thead
    tr
      th ID
      th Token
      th Account
      th Client
      th Scope
      th Status
      th Created
      th Expires
      th Actions
  tbody
    - tokens.each do |token|
      tr
        td = token.id
        td
          i.copy.link.icon data-controller="clipboard" data-action="click->clipboard#click" data-clipboard-text-value=token.token title="Copy Token"
          code = token.token.size > 6 ? "#{token.token[0..2]}…#{token.token[-3..-1]}" : token.token
        td = token.account.username
        td = token.client.client_name
        td = token.scope
        td
          - if token.valid?
            .ui.green.label Valid
          - else
            .ui.red.label Expired
        td = token.created_at.to_s("%Y-%m-%d %H:%M")
        td = token.expires_at.to_s("%Y-%m-%d %H:%M")
        td
          == form_tag(nil, "/admin/oauth/tokens/#{token.id}", method: "DELETE") do
            input.ui.mini.red.button type="submit" value="Delete" data-controller="modal-action" data-action="click->modal-action#show" data-modal="delete-oauth-token" data-modal-token-id=token.id
