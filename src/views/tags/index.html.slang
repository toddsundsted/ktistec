- content_for "title" do
  | ##{hashtag}
turbo-stream-source src="/stream/tags/#{hashtag}"
== tag_page_tag_controls(env, hashtag, task, follow, count)
section.ui.feed data-controller="icon-load-error"
  #refresh-posts-message
  - collection.each do |object|
    == object_partial(env, object)
== paginate(env, collection)
