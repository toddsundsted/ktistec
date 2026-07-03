- content_for "title" do
  | #{feed.name}
- if contents.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.filter.icon
      | There is nothing here, yet.
    .ui.text
      | This page lists the posts in this feed.
- else
  h1 = feed.name
  section.ui.feed data-controller="icon-load-error"
    - contents.each do |object|
      - partial object_partial(env, object)
      - if (reason = Feed::Verdict.find?(feed_id: feed.id, object_iri: object.iri).try(&.reason))
        .ui.small.basic.label = reason
  - partial paginate(env, contents)
