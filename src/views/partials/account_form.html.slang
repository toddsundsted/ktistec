== form_tag(account, form_action) do
  == error_messages(account)
  == input_tag("Username", account, username, autofocus: true)
  == input_tag("Password", account, password, type: "password")
  == input_tag("Display Name", actor, name)
  == input_tag("Summary", actor, summary)
  crystal:
    {% begin %}
      {%
        aliases = ActivityPub::Actor::ALIASES
        subclasses = ActivityPub::Actor.all_subclasses.map(&.stringify)
        types = (aliases + subclasses).sort.reduce({} of String => String) { |h, c| h[c] = c.split("::").last ; h }
      %}
      types = {{types}}
    {% end %}
    selected = actor.type || "ActivityPub::Actor::Person"
  == select_tag("Type", actor, type, types, selected)
  == input_tag("Language", account, language, data: {"controller" => "default-language"})
  == input_tag("Timezone", account, timezone, data: {"controller" => "local-timezone"})
  == submit_button(button_text)
