- content_for "title" do
  | Feeds
- if entries.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.filter.icon
      | You don't have any feeds yet.
    .ui.text
      | A feed is a chronological collection beside your timeline, filled by the posts in your
        inbox that match criteria you choose—keywords, hashtags, and mentions.
    .ui.hidden.divider
    a.ui.primary.button href=new_actor_feed_path(actor) New Feed
- else
  h1 Feeds
  a.ui.primary.button href=new_actor_feed_path(actor) New Feed
  - entries.each do |feed, summary, stats|
    .ui.fluid.card
      .content
        a.header href=actor_feed_path(actor, feed) = feed.name
        .description.feed-summary
          - [{"any", summary.any}, {"all", summary.all}, {"none", summary.none}].each do |selector, terms|
            - if terms.any?
              span.ui.sub.header = selector
              span.ui.labels
                - terms.each do |term|
                  span.ui.label class=term.type = term.label
      .extra.content
        crystal:
          _meta = [pluralize(summary.count, "term"), stats.count > 0 ? pluralize(stats.count, "post") : "no posts"]
          if (_newest = stats.newest)
            _meta << "newest #{distance_of_time_in_words(_newest)} ago"
          end
        = _meta.join(" · ")
      .extra.content
        a.ui.button href=edit_actor_feed_path(actor, feed) Edit
