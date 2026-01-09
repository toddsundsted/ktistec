- if object.draft?
  crystal:
    source_editors = ["rich-text", "markdown"]
    has_content = !object.source.try(&.media_type).nil?
  .ui.mini.compact.buttons
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
        button_classes = ["ui", "button"]
        button_classes << "active" if is_active
        button_classes << "disabled" if has_content
        display_name = editor_name == "rich-text" ? "Rich Text" : "Markdown"
      a class=button_classes.join(" ") href="?editor=#{editor_name}" = display_name
