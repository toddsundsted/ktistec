form.ui.form id="object-#{id}" class=(has_errors ? "error" : nil) data-controller="has-content" method="POST"
  == render "src/views/partials/editor/_editor_errors.html.slang"
  == render "src/views/partials/editor/_editor_hidden_fields.html.slang"
  .field data-turbo-permanent=true
    textarea.markdown-editor data-controller="editor--markdown" data-action="input->editor--markdown#input input->has-content#check" data-has-content-target="input" name="content" rows=3 = content
  == render "src/views/partials/editor/_editor_language_visibility.html.slang"
  == render "src/views/partials/editor/_editor_optional_settings.html.slang"
  == render "src/views/partials/editor/_editor_buttons.html.slang"
