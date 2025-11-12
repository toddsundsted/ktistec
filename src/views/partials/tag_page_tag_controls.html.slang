crystal:
  _task = task
  _follow = follow
turbo-frame#tag_page_tag_controls
  .ui.thread.segments
    .ui.segment
      p: strong
        a href=hashtag_path(hashtag) ##{hashtag}
        - if count > 0
          span< #{pluralize(count, "hashtag")}
      - if env.account?
        - if _task && (_status = fetch_task_status_line(_task))
          p.task
            em = _status
    - if env.account?
      .ui.basic.segment
        - if _follow && !_follow.destroyed?
          == form_button "Unfollow", unfollow_hashtag_path(hashtag)
        - elsif _task && !_task.complete
          == form_button "Cancel", cancel_fetch_hashtag_path(hashtag)
        - else
          form.ui.inline.form method="POST"
            == authenticity_token(env)
            .ui.buttons
              button.ui.primary.button type="submit" formaction=follow_hashtag_path(hashtag) Follow
              button.ui.button type="submit" formaction=start_fetch_hashtag_path(hashtag) Fetch Once
