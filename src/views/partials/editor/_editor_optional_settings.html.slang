- if selected_editors.includes?("optional")
  - unless object.in_reply_to_iri
    .field
      label Title
      input type="text" name="name" value=object.name
    .field
      label Summary
      textarea name="summary" rows="2" = object.summary
    .field
      .ui.checkbox
        input#content-warning type="checkbox" name="sensitive" value="true" checked=object.sensitive
        label for="content-warning" Content warning
    .field class=(object.errors["canonical_path"]? ? "error" : nil)
      label Canonical Path
      input type="text" name="canonical-path" value=object.canonical_path
