- content_for "head" do
  link rel="stylesheet" type="text/css" href="/trix.css"
  script type="text/javascript" src="/trix.js"
section.ui.feed
  crystal:
    _object = object
    _actor = object.attributed_to
    _author = object.attributed_to
  article.event id=anchor(_object)
    == render "src/views/partials/object.html.slang"
- if (_actor = env.current_account?.try(&.actor))
  form.ui.form method="POST" action=actor_relationships_path(_actor, "outbox")
    input type="hidden" name="type" value="Create"
    input type="hidden" name="public" value="true"
    input type="hidden" name="in-reply-to" value=_object.iri
    .field
      input#input-trix-editor type="hidden" name="content"
      trix-editor input="input-trix-editor"
    input.ui.button type="submit" value="Reply"
