a.card href=actor.iri
  .content
    .header= actor.display_name
    .meta= actor.username
  .extra.content
    - if (icon = actor.icon)
      img.ui.mini.image src=icon
    - else
      i.ui.user.icon
    - if (_account = env.account?) && _account.actor != actor
      - if env.request.path !~ /following$/ && (_follow = ActivityPub::Activity::Follow.follows?(actor, _account.actor)) && actor.follows?(_account.actor).try { |r| !r.confirmed }
        == activity_button "Accept", outbox_path(_account), _follow.iri, form_class: "right floated", button_class: "mini accept"
        == activity_button "Reject", outbox_path(_account), _follow.iri, form_class: "right floated", button_class: "mini reject"
      - elsif (_follow = ActivityPub::Activity::Follow.follows?(_account.actor, actor))
        == activity_button "Unfollow", outbox_path(_account), _follow.iri, type: "Undo", form_class: "right floated", button_class: "mini"
      - else
        == activity_button "Follow", outbox_path(_account), actor.iri, form_class: "right floated", button_class: "mini primary"
    - elsif !_account && actor.local?
      form.right.floated method="GET" action=actor_remote_follow_path(actor)
        input.ui.mini.primary.button type="submit" value="Follow"
