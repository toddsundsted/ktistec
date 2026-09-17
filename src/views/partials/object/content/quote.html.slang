- if !show_quote
  .ui.segment.quoted-object
    - if quote
      em Quoted a post by @#{quote.attributed_to.handle}
    - else
      em Quoted a post
- elsif failed
  turbo-frame.ui.segment.quoted-object id=scoped_id(scope, "quote-#{object.id}")
    em Failed to load!
    form.ui.form method="GET" action=fetch_quote_path(object) data-turbo-frame=scoped_id(scope, "quote-#{object.id}")
      button.ui.tiny.button type="submit"
        i.redo.icon
        | Try again
    - if (quote_link = object.quote_display_link)
      a.ui.tiny.iconic.button target="_blank" href=quote_link
        i.external.arrow.icon
        | Quoted post
- elsif quote
  - if quote.deleted? || quote.attributed_to.deleted?
    turbo-frame.ui.segment.quoted-object id=scoped_id(scope, "quote-#{object.id}")
      em This post is deleted!
  - elsif quote.blocked? || quote.attributed_to.blocked?
    turbo-frame.ui.segment.quoted-object id=scoped_id(scope, "quote-#{object.id}")
      em This post is blocked!
  - else
    - if !error_message && (object.draft? || object.quote_approved?(quote))
      turbo-frame.ui.segment.quoted-object id=scoped_id(scope, "quote-#{object.id}")
        section.ui.feed data-controller="icon-load-error"
          - partial object_partial(env, quote, show_quote: false, scope: scope)
    - else
      turbo-frame.ui.segment.quoted-object id=scoped_id(scope, "quote-#{object.id}")
        - if error_message
          em = error_message
        - elsif object.quote_authorization_iri
          em This quote has not been verified.
        - else
          em This quote cannot be verified.
        - if object.quote_authorization_iri
          form.ui.form method="GET" action=fetch_quote_authorization_path(object) data-turbo-frame=scoped_id(scope, "quote-#{object.id}")
            button.ui.tiny.button type="submit"
              i.redo.icon
              | Verify quote
- else
  turbo-frame.ui.segment.quoted-object id=scoped_id(scope, "quote-#{object.id}")
    form.ui.form method="GET" action=fetch_quote_path(object) data-turbo-frame=scoped_id(scope, "quote-#{object.id}")
      button.ui.tiny.button type="submit"
        i.redo.icon
        | Load quoted post
