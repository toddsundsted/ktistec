crystal:
  values = ActivityPub::Object::EditorType.values
  names = ActivityPub::Object::EditorType.names.map(&.underscore.gsub('_', '-'))
  editor_type_map = values.zip(names).to_h
  supported_editors = object.supported_editors.map do |editor_type|
    editor_type_map[editor_type]
  end
  selected_editors =
    if env.params.body.has_key?("editor")
      env.params.body.fetch_all("editor")
    else
      env.params.query.fetch_all("editor")
    end
  warnings = [] of String
  unless selected_editors.empty?
    unsupported_editors = selected_editors - supported_editors
    unless unsupported_editors.empty?
      warnings << %Q|These editors are not supported for this object type: #{unsupported_editors.join(", ")}|
    end
    valid_editors = selected_editors & supported_editors
    selected_source_editors = valid_editors & ["rich-text", "markdown"]
    if selected_source_editors.size > 1
      warnings << %Q|These editors are mutually exclusive: #{selected_source_editors.join(", ")}.|
      valid_editors = valid_editors - selected_source_editors[1..]
    end
    selected_editors = valid_editors
  end
  errors = object.errors
  if (canonical_path_errors = errors["canonical_path.from_iri"]?)
    errors["canonical_path"] = canonical_path_errors
    errors.delete("canonical_path.from_iri")
  end
  errors = errors.transform_keys(&.split(/[_\.]/).map(&.capitalize).join(" "))
  has_errors = !errors.empty?
  content = object.source.try(&.content) || object.content || nil
  actor = env.account.actor
  if (in_reply_to = object.in_reply_to?)
    ancestors = in_reply_to.ancestors
    mentions = (ancestors.map(&.attributed_to.handle).compact.uniq - [actor.handle]).map { |a| "@#{a} " }.join
    content ||= mentions
  end
  unless (media_type = object.source.try(&.media_type))
    if object.new_record?
      if selected_source_editors.nil? || selected_source_editors.empty?
        media_type = env.account.default_editor || "text/html; editor=trix"
      elsif selected_source_editors.first == "markdown"
        media_type = "text/markdown"
      else
        media_type = "text/html; editor=trix"
      end
    else
      media_type = "text/html; editor=trix"
    end
  end
  _object = object
  if _object.responds_to?(:poll?)
    poll = _object.poll?
  end
- unless warnings.empty?
  .ui.warning.message
    .header Editor Selection
    ul.list
      - warnings.each do |warning|
        li = warning
crystal:
  id = object.id || "new" # MOVE ME
  data_controller = media_type.starts_with?("text/html") ? "editor--trix has-content" : "has-content"
form.ui.form id="object-#{id}" class=(has_errors ? "error" : nil) data-controller=data_controller method="POST"
  == render "src/views/partials/editor/_editor_errors.html.slang"
  == render "src/views/partials/editor/_editor_hidden_fields.html.slang"
  .field data-turbo-permanent=true
    - if media_type.starts_with?("text/html")
      trix-editor data-trix-target="trixEditor" data-action="trix-change->has-content#check trix-change->has-content#scheduleAutosave trix-blur->has-content#blur turbo:morph@document->has-content#check" input="editor-input"
      textarea#editor-input data-has-content-target="input" name="content" rows=3 = content
    - else
      textarea.markdown-editor data-controller="editor--markdown" data-action="input->editor--markdown#input input->has-content#check input->has-content#scheduleAutosave blur->has-content#blur" data-has-content-target="input" name="content" rows=3 = content
  == render "src/views/partials/editor/_editor_buttons.html.slang"
  == render "src/views/partials/editor/_editor_language_visibility.html.slang"
  == render "src/views/partials/editor/_editor_optional_settings.html.slang"
  == render "src/views/partials/editor/_editor_poll.html.slang"
  == render "src/views/partials/editor/_editor_actions.html.slang"
