- _account = env.account?
- _emojis = Tag::Emoji.where(subject: actor)
.ui.fluid.actor.card
  - if actor.blocked?
    .blocked.content
      em This actor is blocked!
  - else
    - image = actor.image.presence
    - style = image ? "background-image: url(#{actor.image});" : nil
    .content class=(!image ? "placeholder" : nil) style=style
      - if actor.icon.presence
        img src=actor.icon
      - else
        i.user.icon
  .extra.content
    - if _account
      a.ui.header href=remote_actor_path(actor) == s Ktistec::Emoji.emojify(actor.display_name, _emojis)
    - else
      .ui.header == s Ktistec::Emoji.emojify(actor.display_name, _emojis)
    a.ui.link href=actor.iri = actor.handle
  - if _account && _account.actor != actor
    .extra.content
      - if env.request.path =~ /followers$/ && (follow_relationship = actor.follows?(_account.actor)) && follow_relationship.pending? && (_follow = follow_relationship.activity?)
        == activity_button "Accept", outbox_path(_account), _follow.iri, button_class: "ui button accept"
        == activity_button "Reject", outbox_path(_account), _follow.iri, button_class: "ui button reject"
        == form_button "Block", block_actor_path(actor), button_class: "ui button dangerous", button_data: {"modal": "block.actor", "controller": "modal-action", "action": "click->modal-action#show"}
      - elsif (_follow = _account.actor.follows?(actor).try(&.activity?))
        == activity_button "Unfollow", outbox_path(_account), _follow.iri, type: "Undo"
      - else
        == activity_button "Follow", outbox_path(_account), actor.iri, button_class: "ui button primary"
        == form_button "Block", block_actor_path(actor), button_class: "ui button dangerous", button_data: {"modal": "block.actor", "controller": "modal-action", "action": "click->modal-action#show"}
  - elsif !_account && actor.local?
    .extra.content
      == form_button "Follow", actor_remote_follow_path(actor), method: "GET", button_class: "ui button primary"
