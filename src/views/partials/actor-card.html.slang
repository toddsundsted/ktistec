.ui.fluid.actor.card
  - image = actor.image.presence && "background-image: url(#{actor.image});"
  .content class=(actor.image.presence || "placeholder") style=image
    - if actor.icon.presence
      img src=actor.icon
    - else
      i.user.icon
  - if (summary = actor.summary)
    .extra.summary.content
      p == s summary
  .extra.content
    a.left.floated href=actor.iri
      .meta= actor.display_name
      .meta= actor.account_uri
    - if (_account = env.account?) && _account.actor != actor
      - if env.request.path !~ /following$/ && (_follow = ActivityPub::Activity::Follow.follows?(actor, _account.actor)) && actor.follows?(_account.actor).try { |r| !r.confirmed }
        == activity_button "Accept", outbox_path(_account), _follow.iri, form_class: "ui form right floated", button_class: "ui button accept"
        == activity_button "Reject", outbox_path(_account), _follow.iri, form_class: "ui form right floated", button_class: "ui button reject"
      - elsif (_follow = ActivityPub::Activity::Follow.follows?(_account.actor, actor))
        == activity_button "Unfollow", outbox_path(_account), _follow.iri, type: "Undo", form_class: "ui form right floated"
      - else
        == activity_button "Follow", outbox_path(_account), actor.iri, form_class: "ui form right floated", button_class: "ui button primary"
    - elsif !_account && actor.local?
      == form_button "Follow", actor_remote_follow_path(actor), method: "GET", form_class: "ui form right floated", button_class: "ui button primary"
