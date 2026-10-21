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
  placeholder = "Add a keyword, #hashtag, or @mention, then press Enter"
  judges = feed.new_record? ? Feed::Backend.names.to_h { |name| {name, name} } : {} of String => String
- if judges.size > 1
  form.ui.form method="GET" action=new_actor_feed_path(owner) data-controller="submit-on-change" data-turbo-frame="judge"
    = select_tag("Judge", feed, backend, judges, data: {action: "change->submit-on-change#change"})
    button.ui.button type="submit" data-submit-on-change-target="fallback" Choose
= form_tag(feed, action, data: {controller: "unsaved-changes"}) do
  = error_messages(feed)
  = input_tag("Name", feed, name, placeholder: "e.g. Fediverse")
  = input_tag("Notes", feed, description, placeholder: "A description of what this feed is about.")
  turbo-frame#judge
    - if feed.backend == Feed::Backend::Criteria::NAME
      h3.ui.header Criteria
      p.criteria-hint.plain
        | Start a term with <code>#</code> for a hashtag, <code>@</code>
          for a mention, or just type keywords. <em>One term per line.</em>
      p.criteria-hint.enhanced
        | Start a term with <code>#</code> for a hashtag, <code>@</code>
          for a mention, or just type keywords. <em>Press Enter to add
          each.</em>
      / note the morphing protection (`data-turbo-permanent=true`)
      .ui.field.criteria-builder
        .ui.segment.feed-bucket.any data-turbo-permanent=true data-controller="criteria-input" data-criteria-input-placeholder-value=placeholder
          .ui.small.header
            | Any of these
          textarea name="any" rows="3" data-criteria-input-target="textarea" = criteria[:any]
        .ui.horizontal.divider and
        .ui.segment.feed-bucket.all data-turbo-permanent=true data-controller="criteria-input" data-criteria-input-placeholder-value=placeholder
          .ui.small.header
            | All of these
            span.ui.mini.basic.label< optional
          textarea name="all" rows="2" data-criteria-input-target="textarea" = criteria[:all]
        .ui.horizontal.divider.stop but
        .ui.segment.feed-bucket.none data-turbo-permanent=true data-controller="criteria-input" data-criteria-input-placeholder-value=placeholder
          .ui.small.header
            | None of these
            span.ui.mini.basic.label< optional
          textarea name="none" rows="2" data-criteria-input-target="textarea" = criteria[:none]
    - Feed::Backend.find?(feed.backend).try(&.declared_params).try &.each do |param|
      - if (type = param.type)
        - input_type = type.integer? ? "number" : "text"
        - value = feed.params[param.name]?.try(&.raw.to_s)
        .field
          label = param.name.split(/[-_]/).join(" ", &.capitalize)
          input type=input_type name="params[#{param.name}]" value=value required=param.required
    / last, so the field above keeps its margin
    input type="hidden" name="backend" value=feed.backend
  .ui.buttons
    button.ui.primary.button type="submit" = submit_label
    button.ui.button type="submit" name="preview" value="1" Preview Feed
  a.ui.right.floated.teal.button href=cancel_path = cancel_label
