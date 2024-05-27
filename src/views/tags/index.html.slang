- content_for "title" do
  | ##{hashtag}
== tag_page_tag_controls(env, hashtag, task, follow, count)
section.ui.feed data-controller="icon-load-error"
  - collection.each do |object|
    == object_partial(env, object)
== paginate(env, collection)
