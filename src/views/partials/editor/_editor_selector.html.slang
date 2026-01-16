- if object.draft?
  crystal:
    source_editors = ["rich-text", "markdown"]
    has_content = !object.source.try(&.media_type).nil?
    poll_active = selected_editors.includes?("poll")
    has_options = poll && !poll.options.empty?
  .editors data-turbo-prefetch="false"
    - source_editors.each do |editor_name|
      crystal:
        is_active =
          if !selected_source_editors.nil? && !selected_source_editors.empty?
            selected_source_editors.includes?(editor_name)
          elsif editor_name == "rich-text"
            media_type.starts_with?("text/html")
          else
            media_type.starts_with?("text/markdown")
          end
        button_classes = ["ui", "mini", "compact", "toggle", "button"]
        button_classes << "active" if is_active
        button_classes << "disabled" if has_content
        editor_params = URI::Params.new
        editor_params.add("editor", editor_name)
        editor_params.add("editor", "poll") if poll_active
        display_name = editor_name == "rich-text" ? "Rich Text" : "Markdown"
      a class=button_classes.join(" ") href="?#{editor_params}" = display_name
    - if supported_editors.includes?("poll")
      crystal:
        current_source = selected_source_editors.try(&.first?) || (media_type.starts_with?("text/markdown") ? "markdown" : "rich-text")
        button_classes = ["ui", "mini", "compact", "toggle", "button"]
        button_classes << "active" if poll_active
        button_classes << "disabled" if has_options
        editor_params = URI::Params.new
        editor_params.add("editor", current_source)
        editor_params.add("editor", "poll") unless poll_active
      a class=button_classes.join(" ") href="?#{editor_params}" Include Poll
