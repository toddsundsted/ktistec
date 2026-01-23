- if selected_editors.includes?("poll") && !in_reply_to
  crystal:
    timezone = env.account.timezone.try { |tz| Time::Location.load(tz) }
    if poll
      poll_options = poll.options.map(&.name)
      poll_duration = poll.closed_at.try(&.to_unix)
      poll_closed_at_formatted =
        if (closed_at = poll.closed_at) && timezone
          closed_at.in(timezone).to_s("%b %d, %Y %H:%M %Z")
        elsif closed_at
          closed_at.to_s("%b %d, %Y %H:%M %Z")
        end
      is_86400 = poll_duration == 86400
      is_259200 = poll_duration == 259200
      is_604800 = poll_duration == 604800
      poll_multiple_choice = poll.multiple_choice
    else
      poll_options = [] of String
      poll_duration = nil
      poll_closed_at_formatted = nil
      is_86400 = true
      is_259200 = false
      is_604800 = false
      poll_multiple_choice = false
    end
    is_published = !!object.published
    disabled_class = is_published ? "disabled" : nil
    poll_option_error_class = errors.has_key?("poll.options") ? "error" : nil
    poll_option_field_class = [poll_option_error_class, disabled_class].compact.join(" ")
    poll_option_field_class = nil if poll_option_field_class.empty?
  .ui.two.fields
    .required.field class=poll_option_field_class
      label Poll Option
      input type="text" name="poll-options" value=poll_options[0]? required=true
    .required.field class=poll_option_field_class
      label Poll Option
      input type="text" name="poll-options" value=poll_options[1]? required=true
  .ui.two.fields
    .field class=poll_option_field_class
      label Poll Option
      input type="text" name="poll-options" value=poll_options[2]?
    .field class=poll_option_field_class
      label Poll Option
      input type="text" name="poll-options" value=poll_options[3]?
  .ui.inline.fields
    .field class=disabled_class
      - if is_published && poll_duration
        label Poll Expiration
        input type="hidden" name="poll-duration" value=poll_duration
        input type="text" disabled=true value=poll_closed_at_formatted
      - else
        label Poll Duration
        select.ui.dropdown name="poll-duration"
          option value="" No expiration
          option value="86400" selected=is_86400 1 day
          option value="259200" selected=is_259200 3 days
          option value="604800" selected=is_604800 7 days
    .field class=disabled_class
      .ui.checkbox
        input#p-m-c type="checkbox" name="poll-multiple-choice" value="true" checked=poll_multiple_choice
        label for="p-m-c" Multiple Choice
