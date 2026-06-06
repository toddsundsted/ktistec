- content_for "title" do
  | @#{mention}
- if env.account?
  - unless Ktistec::ViewHelper.cursor_paginated?(env.params.query)
    turbo-stream-source src=stream_path("mentions", mention)
- partial mention_page_mention_banner(env, mention, follow, count)
section.ui.feed data-controller="icon-load-error"
  #refresh-posts-message
  - collection.each do |object|
    - partial object_partial(env, object)
- partial paginate(env, collection)
