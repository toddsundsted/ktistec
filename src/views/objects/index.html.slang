section.ui.feed
  - drafts.each do |_object|
    crystal:
      _actor = _object.attributed_to
      _author = _object.attributed_to
    article.event id=anchor(_object)
      == render "src/views/partials/object.html.slang"
