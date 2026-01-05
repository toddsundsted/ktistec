- content_for "title" do
  | OAuth Clients

h1.ui.header OAuth Clients

.ui.segment
  h3.ui.header Add New Client
  == form_tag(new_client, "/admin/oauth/clients", class: "ui small form") do
    == error_messages(new_client)
    == input_tag("Client Name", new_client, client_name, placeholder: "Client name")
    == input_tag("Redirect URIs", new_client, redirect_uris, placeholder: "Space-separated list of redirect URIs")
    == submit_button("Create Client")

table.ui.table
  thead
    tr
      th Client Name
      th Client ID
      th Client Secret
      th Registration Type
      th Created
      th Last Accessed
      th Actions
  tbody
    - clients.each do |client|
      tr
        td = client.client_name
        td
          i.copy.link.icon data-controller="clipboard" data-action="click->clipboard#click" data-clipboard-text-value=client.client_id title="Copy Client ID"
          code = client.client_id.size > 6 ? "#{client.client_id[0..2]}…#{client.client_id[-3..-1]}" : client.client_id
        td
          i.copy.link.icon data-controller="clipboard" data-action="click->clipboard#click" data-clipboard-text-value=client.client_secret title="Copy Client Secret"
          code
            | ********
        td
          - if client.manual
            .ui.blue.label Manual
          - else
            .ui.grey.label Dynamic
        td = client.created_at.to_s("%Y-%m-%d %H:%M")
        td
          - if (last_accessed_at = client.last_accessed_at)
            = last_accessed_at.to_s("%Y-%m-%d %H:%M")
          - else
            em Never
        td
          == form_tag(nil, "/admin/oauth/clients/#{client.id}", method: "DELETE") do
            input.ui.mini.red.button type="submit" value="Delete" data-controller="modal-action" data-action="click->modal-action#show" data-modal="delete-oauth-client" data-modal-client-name=client.client_name
