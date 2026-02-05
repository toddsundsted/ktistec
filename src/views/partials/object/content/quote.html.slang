- if failed
  .ui.segment.quoted-object
    em Failed to load!
- elsif quote
  - if quote.deleted? || quote.attributed_to.deleted?
    .ui.segment.quoted-object
      em This post is deleted!
  - elsif quote.blocked? || quote.attributed_to.blocked?
    .ui.segment.quoted-object
      em This post is blocked!
  - else
    turbo-frame.ui.segment.quoted-object id="quote-#{object.id}"
      section.ui.feed data-controller="icon-load-error"
        == object_partial(env, quote)
- else
  turbo-frame.ui.segment.quoted-object id="quote-#{object.id}"
    a.ui.tiny.button href="#" data-turbo-frame="quote-#{object.id}"
      i.redo.icon
      | Load quoted post
