- content_for "title" do
  | Feed: #{feed.name}
- if contents.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.filter.icon
      | There is nothing here yet.
    .ui.text
      | This page lists the posts in this feed.
  #refresh-posts-message
- else
  h1 = feed.name
  #refresh-posts-message
  - partial "feeds/contents"
  - partial paginate(env, contents)
- unless Ktistec::ViewHelper.cursor_paginated?(env.params.query)
  turbo-stream-source src=stream_path("feeds", feed.slug_or_id)
