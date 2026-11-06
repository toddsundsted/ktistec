h1 Labels
section.ui.feed data-controller="icon-load-error"
  - partial Ktistec::ViewHelper.object_partial(env, object, as_context: true)
= form_tag(nil, labels_path(object), data: {controller: "unsaved-changes"}) do
  p.criteria-hint.plain
    | A label can be any word or phrase. <em>One label per line.</em>
  p.criteria-hint.enhanced
    | A label can be any word or phrase. <em>Press Enter to add each.</em>
  .ui.field.criteria-builder
    - placeholder = "Add a label, then press Enter"
    .ui.segment.feed-bucket data-controller="criteria-input" data-criteria-input-placeholder-value=placeholder
      textarea name="labels" rows="4" autofocus=true data-criteria-input-target="textarea" = labels.join("\n")
  button.ui.primary.button type="submit" Save
  a.ui.right.floated.teal.button href=remote_object_path(object) Back
