- content_for "title" do
  | Admin: Accounts
h1.ui.header Accounts
.ui.segment
  a.ui.primary.button href="/admin/accounts/new" Add Account
table.ui.table
  thead
    tr
      th
      th Username
      th Created At
      th Actions
  tbody
    - accounts.each do |account|
      tr id="account-#{account.id}"
        td
          - if env.account? && env.account.id == account.id
            i.large.yellow.chess.queen.icon
        td= account.username
        td= account.created_at.to_s("%Y-%m-%d %H:%M")
        td
          .ui.small.buttons
            a.ui.button href="/actors/#{account.actor.username}" Profile
