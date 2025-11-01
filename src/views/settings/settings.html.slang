- content_for "head" do
  link rel="stylesheet" href="/dist/settings.css"
  script src="/dist/settings.bundle.js"
- content_for "title" do
  | Settings
== _view_src_views_partials_actor_panel_html_slang(env, actor)
h1 Account Settings
p
  | Settings for account <strong>#{actor.username}</strong>.
== form_tag(account, "/settings/actor", form: "data") do
  == error_messages(account)
  == input_tag("Display Name", actor, name)
  == input_tag("Summary", actor, summary)
  == input_tag("Language", account, language, data: {"controller" => "default-language", "placeholder-only" => true})
  == input_tag("Timezone", account, timezone, data: {"controller" => "local-timezone", "placeholder-only" => true})
  == input_tag("Password", account, password, type: "password", placeholder: "Leave blank to leave unchanged")
  .field
    .ui.checkbox
      input type="checkbox" name="auto_approve_followers" value="1" checked=account.auto_approve_followers
      label Automatically approve new followers
  crystal:
    attachments = actor.attachments || [] of ActivityPub::Actor::Attachment
    attachments.size.upto(ActivityPub::Actor::ATTACHMENT_LIMIT - 1) do |i|
      attachments << ActivityPub::Actor::Attachment.new("", "", "")
    end
  .field
    label Metadata
    p You can have up to four items displayed on your profile.
  .two.fields
    .field
      label Name
    .field
      label Value
  - 0.upto(ActivityPub::Actor::ATTACHMENT_LIMIT - 1).each do |i|
    .two.fields
      .field
        input type="text" name="attachment_#{i}_name" value=attachments[i].name
      .field
        input type="text" name="attachment_#{i}_value" value=attachments[i].value
  == input_tag("Background Image", actor, image, class: "filepond", type: "file")
  == input_tag("Profile Image", actor, icon, class: "filepond", type: "file")
  == submit_button("Update")
h2 Delete Account!
p
  | Delete account <strong>#{actor.username}</strong>. This action cannot be undone!
== form_tag(nil, "/settings/terminate") do
  input.ui.dangerous.button type="submit" value="Delete Account" data-modal="terminate" data-controller="modal-action" data-action="click->modal-action#show"
.ui.basic.tiny.terminate.modal
  .header
    i.trash.icon
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
  == trix_editor("Description", settings, description)
  == input_tag("Footer", settings, footer)
  crystal:
    can_deepl = ENV["DEEPL_API_KEY"]?
    can_libretranslate = ENV["LIBRETRANSLATE_API_KEY"]?
    service = settings.translator_service
    is_deepl = service == "deepl"
    is_libretranslate = service == "libretranslate"
  - if can_deepl || can_libretranslate
    .inline.fields
      label for="translator_service" Use Translator Service
      - if can_deepl
        .field
          .ui.radio.checkbox
            input#deepl-service type="radio" name="translator_service" value="deepl" checked=is_deepl
            label for="deepl-service" DeepL
      - if can_libretranslate
        .field
          .ui.radio.checkbox
            input#libretranslate-service type="radio" name="translator_service" value="libretranslate" checked=is_libretranslate
            label for="libretranslate-service" LibreTranslate
      .field
        .ui.radio.checkbox
          input#no-service type="radio" name="translator_service" value="" checked=(!is_deepl && !is_libretranslate)
          label for="no-service" None
    .field
      label Translator Service URL
      input type="text" name="translator_url" value=settings.translator_url
    p.ui.documentation: em
      | If you are struggling to get translation to work, enable debug logging
        for the translator(s) <a href="/system">here</a>.
  - else
    p.ui.documentation
      | In order to translate posts, sign up for a service
        (both <a href="https://www.deepl.com/" target="_blank">DeepL</a>
        and <a href="https://libretranslate.com/" target="_blank">LibreTranslate</a>
        are supported) and add the API key to the Ktistec
        server process environment (as either environment variable
        <code>DEEPL_API_KEY</code> or <code>LIBRETRANSLATE_API_KEY</code>,
        depending on the service) and restart the server. Configuration
        options will replace this text.
  == submit_button("Update")
p.small.text Ktistec Version #{Ktistec::VERSION}
br.transition.hidden
