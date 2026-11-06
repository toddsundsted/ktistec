h1 Labels
section.ui.feed data-controller="icon-load-error"
  - partial Ktistec::ViewHelper.object_partial(env, object, as_context: true)
= form_tag(nil, labels_path(object), data: {controller: "unsaved-changes"}) do
  p.term-hint.plain
    | A label can be any word or phrase. <em>One label per line.</em>
  p.term-hint.enhanced
    | A label can be any word or phrase. <em>Press Enter to add each.</em>
  .ui.field.term-builder
    - placeholder = "Add a label, then press Enter"
    .ui.segment.term-input data-controller="term-input" data-term-input-placeholder-value=placeholder
      textarea name="labels" rows="4" autofocus=true data-term-input-target="textarea" = labels.join("\n")
  button.ui.primary.button type="submit" Save
  a.ui.right.floated.teal.button href=remote_object_path(object) Back
