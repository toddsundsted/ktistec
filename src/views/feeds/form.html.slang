crystal:
  if feed.new_record?
    action = actor_feeds_path(actor)
    submit_label = "Create Feed"
    cancel_path = actor_feeds_path(actor)
  else
    action = actor_feed_path(actor, feed)
    submit_label = "Save"
    cancel_path = actor_feed_path(actor, feed)
  end
= form_tag(feed, action, method: "POST") do
  = error_messages(feed)
  = input_tag("Name", feed, name, placeholder: "e.g. Fediverse")
  = input_tag("Notes", feed, description, placeholder: "A description of what this feed is about.")
  h3.ui.header Criteria
  p
    | Start a term with <code>#</code> for a hashtag, <code>@</code>
      for a mention, or just type keywords. <em>One term per line.</em>
  .ui.field.criteria-builder
    .ui.segment.feed-bucket.any
      .ui.small.header
        | Any of these
      textarea name="any" rows="3" = any
    .ui.horizontal.divider and
    .ui.segment.feed-bucket.all
      .ui.small.header
        | All of these
        span.ui.mini.basic.label< optional
      textarea name="all" rows="2" = all
    .ui.horizontal.divider.stop but
    .ui.segment.feed-bucket.none
      .ui.small.header
        | None of these
        span.ui.mini.basic.label< optional
      textarea name="none" rows="2" = none
  = submit_button(submit_label)
  a.ui.basic.button href=cancel_path Cancel
