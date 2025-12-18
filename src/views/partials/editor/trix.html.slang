form.ui.form id="object-#{id}" class=(has_errors ? "error" : nil) data-controller="editor--trix has-content" method="POST"
  == render "src/views/partials/editor/_editor_errors.html.slang"
  == render "src/views/partials/editor/_editor_hidden_fields.html.slang"
  .field data-turbo-permanent=true
    trix-editor data-trix-target="trixEditor" data-action="trix-attachment-add->editor--trix#add trix-attachment-remove->editor--trix#remove trix-change->editor--trix#change trix-change->has-content#check turbo:morph@document->has-content#check" input="editor-input"
    textarea#editor-input data-has-content-target="input" name="content" rows=3 = content
  == render "src/views/partials/editor/_editor_language_visibility.html.slang"
  == render "src/views/partials/editor/_editor_optional_settings.html.slang"
  == render "src/views/partials/editor/_editor_buttons.html.slang"
