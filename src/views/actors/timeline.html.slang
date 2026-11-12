- unless Ktistec::ViewHelper.cursor_paginated?(env.params.query)
  turbo-stream-source src=stream_path("actor", "homepage", query: env.request.query)
- objects = timeline.map(&.object)
- partial "partials/timeline/posts"
- partial paginate(env, timeline)
