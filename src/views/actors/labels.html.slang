- content_for "title" do
  | Labels
- if names.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.tag.icon
      | There is nothing here yet.
    .ui.text
      | This page lists your private labels. You can label a post by clicking
      span.ui.small.primary.label<> §+
      | on the details page of any post.
- else
  h1 Labels
  .ui.labels
    - names.each do |name|
      a.ui.small.primary.label href=actor_label_path(actor, name) §#{name}
