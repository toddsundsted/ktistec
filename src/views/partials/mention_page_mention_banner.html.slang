turbo-frame#mention_page_mention_banner
  .ui.thread.segments
    .ui.segment
      p
        a href=mention_path @#{mention}
        - if count > 0
          span< #{pluralize(count, "mention")}
    - if env.account?
      .ui.basic.segment
        - if follow.nil? || follow.new_record?
          == form_button "Follow", follow_mention_path, button_class: "ui button primary"
        - else
          == form_button "Unfollow", unfollow_mention_path
