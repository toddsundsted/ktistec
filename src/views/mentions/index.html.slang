- content_for "title" do
  | @#{mention}
- if env.account?
  .ui.thread.segments
    .ui.segment
      p
        a href=mention_path @#{mention}
        - if (match = Tag::Mention.match(mention).first?)
          span< #{match.last} posts
    turbo-frame#mention_page_mention_controls
      .ui.basic.segment
        - if follow
          == form_button "Unfollow", unfollow_mention_path
        - else
          == form_button "Follow", follow_mention_path, button_class: "ui button primary"
section.ui.feed
  - collection.each do |object|
    == object_partial(env, object)
== paginate(env, collection)
