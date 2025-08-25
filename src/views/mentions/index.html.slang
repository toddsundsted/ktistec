- content_for "title" do
  | @#{mention}
- if env.account?
  - if (env.params.query["page"]?.try(&.to_i) || 1) == 1
    turbo-stream-source src="/stream/mentions/#{mention}"
== mention_page_mention_banner(env, mention, follow, count)
section.ui.feed data-controller="icon-load-error"
  #refresh-posts-message
  - collection.each do |object|
    == object_partial(env, object)
== paginate(env, collection)
