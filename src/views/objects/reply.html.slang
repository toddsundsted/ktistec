section.ui.feed
  == object_partial(env, object)
- if (actor = env.account?.try(&.actor))
  crystal:
    author = object.attributed_to
    ancestors = object.ancestors
  form.ui.form data-controller="has-content multi-action" data-action="submit->multi-action#squelch" method="POST"
    input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
    input type="hidden" name="type" value="Publish"
    input type="hidden" name="public" value="true"
    input type="hidden" name="to" value=author.iri
    - value = (ancestors.map(&.attributed_to_iri).compact.uniq - [author.iri]).join(",")
    input type="hidden" name="cc" value=value
    input type="hidden" name="in-reply-to" value=object.iri
    .field
      - value = ancestors.map(&.attributed_to.account_uri).compact.uniq.map { |a| "@#{a} " }.join
      input#input-trix-editor type="hidden" name="content" value=value
      trix-editor data-controller="trix" data-action="trix-attachment-add@window->trix#add trix-attachment-remove@window->trix#remove trix-change@window->trix#change input->has-content#change" data-has-content-target="input" input="input-trix-editor"
    .ui.buttons
      input.ui.disabled.primary.button data-has-content-target="button" data-action="click->multi-action#submit" type="submit" value="Reply" action=outbox_path(actor)
