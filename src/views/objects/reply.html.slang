crystal:
  actor = env.account.actor
  in_reply_to = object
  object = ActivityPub::Object.new(iri: "#{host}/objects/reply", attributed_to: actor, in_reply_to: in_reply_to)
  # preserve content warning
  if (_summary = in_reply_to.summary) && (_sensitive = in_reply_to.sensitive)
    object.assign(summary: _summary, sensitive: _sensitive)
  end
h1 Reply
section.ui.feed data-controller="icon-load-error"
  == Ktistec::ViewHelper.object_partial(env, in_reply_to, in_reply: true)
== render "src/views/partials/editor.html.slang"
br
