- content_for "title" do
  | Bookmarks
- if objects.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.bookmark.icon
      | There is nothing here, yet.
    .ui.text
      | This page lists your bookmarked posts.
        You can bookmark posts by clicking the bookmark button on any post.
- else
  h1 Bookmarks
  section.ui.feed data-controller="icon-load-error"
    - objects.each do |object|
      == object_partial(env, object)
  == paginate(env, objects)
