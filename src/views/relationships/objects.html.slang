- content_for "title" do
  = title
- if objects.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.exclamation.icon
      | There is nothing here, yet.
    .ui.text
      | This page lists your #{title.downcase}.
- else
  h1= title
  section.ui.feed
    - objects.each do |object|
      == object_partial(env, object)
  == paginate(env, objects)
