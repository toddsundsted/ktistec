crystal:
  owner = feed.owner
  if feed.new_record?
    action = actor_feeds_path(owner)
    cancel_path = actor_feeds_path(owner)
    cancel_label = "Cancel"
  else
    action = actor_feed_path(owner, feed)
    cancel_path = back_path(actor_feeds_path(owner))
    cancel_label = "Back"
  end
  submit_label = (feed.new_record? || feed.draft) ? "Create Feed" : "Update Feed"
  placeholder = "Add a keyword, #hashtag, or @mention…"
= form_tag(feed, action, data: {controller: "unsaved-changes"}) do
  = error_messages(feed)
  = input_tag("Name", feed, name, placeholder: "e.g. Fediverse")
  = input_tag("Notes", feed, description, placeholder: "A description of what this feed is about.")
  h3.ui.header Criteria
  p
    | Start a term with <code>#</code> for a hashtag, <code>@</code>
      for a mention, or just type keywords. <em>One term per line.</em>
  .ui.field.criteria-builder
    .ui.segment.feed-bucket.any data-controller="criteria-input" data-criteria-input-placeholder-value=placeholder
      .ui.small.header
        | Any of these
      textarea name="any" rows="3" data-criteria-input-target="textarea" = criteria[:any]
    .ui.horizontal.divider and
    .ui.segment.feed-bucket.all data-controller="criteria-input" data-criteria-input-placeholder-value=placeholder
      .ui.small.header
        | All of these
        span.ui.mini.basic.label< optional
      textarea name="all" rows="2" data-criteria-input-target="textarea" = criteria[:all]
    .ui.horizontal.divider.stop but
    .ui.segment.feed-bucket.none data-controller="criteria-input" data-criteria-input-placeholder-value=placeholder
      .ui.small.header
        | None of these
        span.ui.mini.basic.label< optional
      textarea name="none" rows="2" data-criteria-input-target="textarea" = criteria[:none]
  .ui.buttons
    button.ui.primary.button type="submit" = submit_label
    button.ui.button type="submit" name="preview" value="1" Preview Feed
  a.ui.right.floated.teal.button href=cancel_path = cancel_label
