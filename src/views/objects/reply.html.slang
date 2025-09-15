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
    .field
      trix-editor data-controller="trix" data-action="trix-attachment-add->trix#add trix-attachment-remove->trix#remove trix-change->trix#change trix-initialize->has-content#check input->has-content#check" data-has-content-target="input" input="editor-input"
      textarea#editor-input name="content" rows=3 = mentions
    / don't use `object.language` -- `object` is the post being replied to!
    - if (language = env.account.language.presence)
      .inline.fields
        .nine.wide.field
          == render "src/views/partials/visibility_controls.html.slang"
        .seven.wide.field
          label Language
          input type="text" name="language" value=language
    - else
      .inline.fields
        == render "src/views/partials/visibility_controls.html.slang"
    .ui.buttons
      input.ui.primary.button data-has-content-target="button" type="submit" value="Reply" formaction=outbox_path(actor)
br.transition.hidden
