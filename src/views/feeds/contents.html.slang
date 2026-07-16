section.ui.feed data-controller="icon-load-error"
  - contents.each do |object|
    - partial object_partial(env, object)
    - if (reason = Feed::Verdict.find?(feed: feed, object: object).try(&.reason))
      .ui.small.basic.label = reason
