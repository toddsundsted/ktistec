- content_for "title" do
  | Feed: #{feed.name}
- if contents.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.filter.icon
      | There is nothing here, yet.
    .ui.text
      | This page lists the posts in this feed.
- else
  h1 = feed.name
  - partial "feeds/contents"
  - partial paginate(env, contents)
