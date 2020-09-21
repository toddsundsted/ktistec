section.ui.feed
  - thread.each do |_object|
    crystal:
      _actor = _object.attributed_to
      _author = _object.attributed_to
    article.threaded.event id=anchor(_object) class=depth(_object)
      == render "src/views/partials/object.html.slang"
