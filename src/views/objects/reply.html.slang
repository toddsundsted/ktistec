section.ui.feed data-controller="icon-load-error"
  == object_partial(env, object)
- if (actor = env.account?.try(&.actor))
  crystal:
    author = object.attributed_to
    ancestors = object.ancestors
    mentions = (ancestors.map(&.attributed_to.handle).compact.uniq - [actor.handle]).map { |a| "@#{a} " }.join
  form.ui.form id="object-new" data-controller="trix has-content" method="POST"
    input type="hidden" name="authenticity_token" value=env.session.string?("csrf")
    input type="hidden" name="type" value="Publish"
    input type="hidden" name="in-reply-to" value=object.iri
    .field data-turbo-permanent=true
      trix-editor data-trix-target="trixEditor" data-action="trix-attachment-add->trix#add trix-attachment-remove->trix#remove trix-change->trix#change trix-initialize->has-content#check input->has-content#check" data-has-content-target="input" input="editor-input"
      textarea#editor-input name="content" rows=3 = mentions
    / don't use `object.language` -- `object` is the post being replied to!
    - if (language = env.account.language.presence)
      .inline.fields
        .ten.wide.field
          == render "src/views/partials/visibility_controls.html.slang"
        .six.wide.field
          label Language
          input type="text" name="language" value=language
    - else
      .inline.fields
        == render "src/views/partials/visibility_controls.html.slang"
    .ui.buttons
      button.ui.primary.button data-has-content-target="button" type="submit" formaction=outbox_path(actor)
        | Send Reply
      button.ui.button data-has-content-target="button" data-trix-target="saveDraftButton" type="submit" formaction=objects_path
        | Create Draft
br.transition.hidden
