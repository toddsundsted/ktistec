== form_tag(account, form_action) do
  == error_messages(account)
  == input_tag("Username", account, username, autofocus: true)
  == input_tag("Password", account, password, type: "password")
  == input_tag("Display Name", actor, name)
  == input_tag("Summary", actor, summary)
  == input_tag("Language", account, language, data: {"controller" => "default-language"})
  == input_tag("Timezone", account, timezone, data: {"controller" => "local-timezone"})
  == submit_button(button_text)
