section.ui.feed data-controller="icon-load-error"
  == object_partial(env, object)
- if (actor = env.account?.try(&.actor))
  crystal:
    author = object.attributed_to
    ancestors = object.ancestors
    mentions = (ancestors.map(&.attributed_to.handle).compact.uniq - [actor.handle]).map { |a| "@#{a} " }.join
  form.ui.form data-controller="has-content" method="POST"
    input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
    input type="hidden" name="type" value="Publish"
    input type="hidden" name="in-reply-to" value=object.iri
    input type="hidden" name="public" value="true"
    .field
      trix-editor data-controller="trix" data-action="trix-attachment-add@window->trix#add trix-attachment-remove@window->trix#remove trix-initialize->has-content#check input->has-content#check" data-has-content-target="input" input="editor-input"
      textarea#editor-input name="content" rows=3 = mentions
    .ui.buttons
      input.ui.primary.button data-has-content-target="button" type="submit" value="Reply" formaction=outbox_path(actor)
br.transition.hidden
