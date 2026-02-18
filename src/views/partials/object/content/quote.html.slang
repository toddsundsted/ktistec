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
    - if !error_message && (object.attributed_to == quote.attributed_to || object.quote_authorization?)
      turbo-frame.ui.segment.quoted-object id="quote-#{object.id}"
        section.ui.feed data-controller="icon-load-error"
          == object_partial(env, quote)
    - else
      turbo-frame.ui.segment.quoted-object id="quote-#{object.id}"
        - if error_message
          em = error_message
        - elsif object.quote_authorization_iri
          form.ui.form method="GET" action=fetch_quote_authorization_path(object) data-turbo-frame="quote-#{object.id}"
            button.ui.tiny.button type="submit"
              i.redo.icon
              | Verify quote
            em This quote has not been verified.
        - else
          em This quote cannot be verified.
- else
  turbo-frame.ui.segment.quoted-object id="quote-#{object.id}"
    form.ui.form method="GET" action=fetch_quote_path(object) data-turbo-frame="quote-#{object.id}"
      button.ui.tiny.button type="submit"
        i.redo.icon
        | Load quoted post
