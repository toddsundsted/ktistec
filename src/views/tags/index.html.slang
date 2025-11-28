- content_for "title" do
  | ##{hashtag}
- if env.account?
  - if (env.params.query["page"]?.try(&.to_i) || 1) == 1
    turbo-stream-source src="/stream/tags/#{hashtag}"
== tag_page_tag_controls(env, hashtag, task, follow, count)
section.ui.feed data-controller="icon-load-error"
  #refresh-posts-message
  - collection.each do |object|
    - if env.account?
      crystal:
        _highlight = if cutoff_time
          object.created_at > cutoff_time
        end
      == object_partial(env, object, highlight: _highlight)
    - else
      crystal:
        _activity = object.activities.find! do |activity|
          Relationship::Content::Outbox.find?(activity: activity)
        end
      == object_partial(env, object, activity: _activity, actor: _activity.actor, author: object.attributed_to)
== paginate(env, collection)
