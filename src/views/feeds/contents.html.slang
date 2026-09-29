section.ui.feed data-controller="icon-load-error"
  - contents.each do |object|
    - partial object_partial(env, object)
    - if (reason = Feed::Verdict.find?(version_id: feed.version_id, object_iri: object.iri).try(&.reason))
      /! #{reason}
