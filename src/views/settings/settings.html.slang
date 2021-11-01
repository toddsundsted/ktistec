- content_for "head" do
  script src="/dist/settings.bundle.js"
== render "src/views/partials/actor-panel.html.slang"
h1 User Settings
== form_tag(account, "/settings/actor") do
  == error_messages(account)
  == input_tag("Display Name", actor, name)
  == input_tag("Summary", actor, summary)
  == input_tag("Timezone", account, timezone, data: {"controller" => "local-timezone"})
  == input_tag("Background Image", actor, image, class: "filepond", type: "file")
  == input_tag("Profile Image", actor, icon, class: "filepond", type: "file")
  input.ui.primary.button type="submit" value="Update"
h2 Delete Account!
== form_tag(nil, "/settings/terminate") do
  input.ui.dangerous.button type="submit" value="Delete Account" data-modal="terminate"
.ui.basic.tiny.terminate.modal
  .header: i.trash.icon
    | Delete This Account
  .content
    p
      | This action will delete this account and all its posts on this
        instance and on all federated instances, and it <strong>cannot
        be undone</strong>. Are you certain you want to delete this
        account?
  .actions
    .ui.red.basic.cancel.inverted.button
      i.remove.icon
      | No
    .ui.green.ok.inverted.button
      i.checkmark.icon
      | Yes
h1 Site Settings
== form_tag(settings, "/settings/service") do
  == error_messages(settings)
  == input_tag("Site Name", settings, site)
  == input_tag("Footer", settings, footer)
  input.ui.primary.button type="submit" value="Update"
br
