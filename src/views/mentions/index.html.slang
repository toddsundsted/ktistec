- content_for "title" do
  | @#{mention}
== mention_page_mention_banner(env, mention, follow, count)
section.ui.feed data-controller="icon-load-error"
  - collection.each do |object|
    == object_partial(env, object)
== paginate(env, collection)
