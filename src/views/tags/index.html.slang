- content_for "title" do
  | ##{hashtag}
- if env.account?
  - if !env.params.query["max_id"]? && !env.params.query["min_id"]?
    turbo-stream-source src=stream_path("tags", hashtag)
- partial tag_page_tag_controls(env, hashtag, task, follow, count)
section.ui.feed data-controller="icon-load-error"
  #refresh-posts-message
  - collection.each do |object|
    - if env.account?
      crystal:
        _highlight = if cutoff_time
          object.created_at > cutoff_time
        end
      - partial object_partial(env, object, highlight: _highlight)
    - else
      crystal:
        _activity = object.activities.find! do |activity|
          Relationship::Content::Outbox.find?(activity: activity)
        end
      - partial object_partial(env, object, activity: _activity, actor: _activity.actor, author: object.attributed_to)
- partial paginate(env, collection)
