crystal:
  actor = env.account.actor
  in_reply_to = object
  object = ActivityPub::Object.new(iri: "#{host}/objects/reply", attributed_to: actor, in_reply_to: in_reply_to)
h1 Reply
section.ui.feed data-controller="icon-load-error"
  == Ktistec::ViewHelper.object_partial(env, in_reply_to)
== render "src/views/partials/editor.html.slang"
br
