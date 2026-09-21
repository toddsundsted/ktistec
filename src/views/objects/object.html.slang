- content_for "og_metadata" do
  - unless object.draft?
    - partial "partials/object/og_metadata"
- if env.account? && !object.draft?
  turbo-stream-source src=stream_path("objects", object.id)
section.ui.feed data-controller="icon-load-error"
  - partial object_partial(env, object, with_detail: true)
