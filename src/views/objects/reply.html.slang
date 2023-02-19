section.ui.feed
  == object_partial(env, object)
- if (actor = env.account?.try(&.actor))
  crystal:
    author = object.attributed_to
    ancestors = object.ancestors
    mentions = (ancestors.map(&.attributed_to.account_uri).compact.uniq - [actor.account_uri]).map { |a| "@#{a} " }.join
  form.ui.form data-controller="has-content multi-action" data-action="submit->multi-action#squelch" method="POST"
    input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
    input type="hidden" name="type" value="Publish"
    input type="hidden" name="in-reply-to" value=object.iri
    input type="hidden" name="public" value="true"
    .field
      input#input-trix-editor type="hidden" name="content" value=mentions
      trix-editor data-controller="trix" data-action="trix-attachment-add@window->trix#add trix-attachment-remove@window->trix#remove trix-change@window->trix#change input->has-content#change" data-has-content-target="input" input="input-trix-editor"
    .ui.buttons
      input.ui.disabled.primary.button data-has-content-target="button" data-action="click->multi-action#submit" type="submit" value="Reply" action=outbox_path(actor)
br.transition.hidden
