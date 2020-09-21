section.ui.feed
  crystal:
    _object = object
    _actor = object.attributed_to
    _author = object.attributed_to
  article.event id=anchor(_object)
    == render "src/views/partials/object.html.slang"
