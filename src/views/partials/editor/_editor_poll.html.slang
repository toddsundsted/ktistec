- if selected_editors.includes?("poll") && !in_reply_to
  crystal:
    if poll
      poll_options = poll.options.map(&.name)
      poll_duration = poll.closed_at.try(&.to_unix)
      is_86400 = poll_duration == 86400
      is_259200 = poll_duration == 259200
      is_604800 = poll_duration == 604800
      poll_multiple_choice = poll.multiple_choice
    else
      poll_options = [] of String
      is_86400 = true
      is_259200 = false
      is_604800 = false
      poll_multiple_choice = false
    end
  - poll_option_classes = object.errors.has_key?("poll.options") ? "error" : nil
  .ui.two.fields
    .required.field class=poll_option_classes
      label Poll Option
      input type="text" name="poll-options" value=poll_options[0]? required=true
    .required.field class=poll_option_classes
      label Poll Option
      input type="text" name="poll-options" value=poll_options[1]? required=true
  .ui.two.fields
    .field class=poll_option_classes
      label Poll Option
      input type="text" name="poll-options" value=poll_options[2]?
    .field class=poll_option_classes
      label Poll Option
      input type="text" name="poll-options" value=poll_options[3]?
  .ui.inline.fields
    .field
      label Poll Duration
      select.ui.dropdown name="poll-duration"
        option value="" No expiration
        option value="86400" selected=is_86400 1 day
        option value="259200" selected=is_259200 3 days
        option value="604800" selected=is_604800 7 days
    .field
      .ui.checkbox
        input#p-m-c type="checkbox" name="poll-multiple-choice" value="true" checked=poll_multiple_choice
        label for="p-m-c" Multiple Choice
