- relationship = env.params.url["relationship"]
- content_for "title" do
  = relationship.titleize
- if objects.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.exclamation.icon
      | There is nothing here, yet.
    .ui.text
      | This page lists your #{relationship}.
- else
  h1= relationship.titleize
  section.ui.feed
    - objects.each do |object|
      == object_partial(env, object)
  == paginate(env, objects)
