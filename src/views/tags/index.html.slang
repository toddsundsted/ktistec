crystal:
  _follow = follow
- content_for "title" do
  | ##{hashtag}
turbo-frame#tag_page_tag_controls
  .ui.thread.segments
    .ui.segment
      p
        a href=hashtag_path ##{hashtag}
        - if count > 0
          span< #{pluralize(count, "hashtag")}
      - if env.account?
        - if (_task = task) && (_status = fetch_task_status_line(_task))
          p.task
            em = _status
    - if env.account?
      .ui.basic.segment
        - if _follow.nil? || _follow.new_record?
          == form_button "Follow", follow_hashtag_path, button_class: "ui button primary"
        - else
          == form_button "Unfollow", unfollow_hashtag_path
section.ui.feed data-controller="icon-load-error"
  - collection.each do |object|
    == object_partial(env, object)
== paginate(env, collection)
