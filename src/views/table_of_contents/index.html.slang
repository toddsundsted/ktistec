- content_for "title" do
  | Table of Contents
- if tree.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.exclamation.icon
      | There are no objects with canonical paths.
- else
  h1 Table of Contents
  .ui.list
    == TableOfContentsController.render_toc_html(tree)
br.transition.hidden
