crystal:
  _sample = feed.draft ? " among the #{FeedsController.preview_limit} most recent posts" : ""
#feed_preview.ui.segment.feed-preview
  - if contents.empty?
    h3.ui.header Preview
    .ui.text No matches yet#{_sample}.
  - else
    h3.ui.header Preview
      - if contents.size >= FeedsController.match_limit
        .sub.header Showing the first #{pluralize(FeedsController.match_limit, "match")}#{_sample}
      - else
        .sub.header Showing all #{pluralize(contents.size, "match")}#{_sample}
    - partial "feeds/contents"
