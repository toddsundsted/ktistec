- if has_errors
  .ui.error.message
    - messages = error_messages.flat_map { |k, vs| vs.map { |v| "#{k} #{v}." } }.join(" ")
    p = messages
