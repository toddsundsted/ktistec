turbo-frame#tag_page_tag_controls
  .ui.thread.segments
    .ui.segment
      p
        a href=hashtag_path(hashtag) ##{hashtag}
        - if count > 0
          span< #{pluralize(count, "hashtag")}
      - if env.account?
        - if task && (status = fetch_task_status_line(task))
          p.task
            em = status
    - if env.account?
      .ui.basic.segment
        - if follow.nil? || follow.new_record?
          == form_button "Follow", follow_hashtag_path(hashtag), button_class: "ui button primary"
        - else
          == form_button "Unfollow", unfollow_hashtag_path(hashtag)
