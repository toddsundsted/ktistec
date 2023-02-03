#thread-fetch.ui.event
  .label
    i.user.outline.icon
  .content
    - if message
      .ui.error.message = message
    p: em
      | The replied to post (
      a href=iri target="_blank" link
      | ) is not locally available. Click "Fetch" to retrieve the
        post and add it to this instance. This can take a while.
    form.ui.inline.form method="POST" action="/remote/objects/fetch"
      == authenticity_token(env)
      input type="hidden" name="iri" value=iri
      input.ui.tiny.button type="submit" value="Fetch"
