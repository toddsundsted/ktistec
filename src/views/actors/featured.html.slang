- content_for "title" do
  | Featured
- if objects.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.pin.icon
      | There is nothing here, yet.
    - if env.account?
      .ui.text
        | This page lists your featured posts.
          You can feature a post by clicking the pin button on any of your posts.
- else
  h1 Featured
  section.ui.feed data-controller="icon-load-error"
    - objects.each do |object|
      == object_partial(env, object)
  == paginate(env, objects)
