section.ui.feed
  crystal:
    _object = object
    _actor = object.attributed_to
    _author = object.attributed_to
  article.event id=anchor(_object)
    == render "src/views/partials/object.html.slang"
- if (_actor = env.account?.try(&.actor))
  form.ui.form method="POST"
    input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
    input type="hidden" name="type" value="Publish"
    input type="hidden" name="public" value="true"
    input type="hidden" name="to" value=_author.iri
    - _ancestors = (ancestors.map(&.attributed_to_iri).compact.uniq - [_author.iri]).join(",")
    input type="hidden" name="cc" value=_ancestors
    input type="hidden" name="in-reply-to" value=_object.iri
    .field
      input#input-trix-editor type="hidden" name="content"
      trix-editor input="input-trix-editor"
    .ui.buttons
      input.ui.disabled.primary.button type="submit" value="Reply" action=outbox_path(_actor)
