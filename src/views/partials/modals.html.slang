.ui.basic.tiny.delete.modal
  .header
    i.trash.icon
    | Delete This Post
  .content
    p
      | This action will delete this post on this instance and on all
        federated instances, and it cannot be undone. Are you certain
        you want to delete this post?
  .actions
    .ui.red.basic.cancel.inverted.button
      i.remove.icon
      | No
    .ui.green.ok.inverted.button
      i.checkmark.icon
      | Yes
.ui.basic.tiny.block.actor.modal
  .header
    i.user.times.icon
    | Block This Actor
  .content
    p
      | This action will block this actor and hide all of their past
        and future posts. Are you certain you want to block this
        actor?
  .actions
    .ui.red.basic.cancel.inverted.button
      i.remove.icon
      | No
    .ui.green.ok.inverted.button
      i.checkmark.icon
      | Yes
.ui.basic.tiny.block.object.modal
  .header
    i.times.icon
    | Block This Object
  .content
    p
      | This action will block this object. Are you certain you want
        to block this object?
  .actions
    .ui.red.basic.cancel.inverted.button
      i.remove.icon
      | No
    .ui.green.ok.inverted.button
      i.checkmark.icon
      | Yes
.ui.basic.tiny.delete-oauth-client.modal
  .header
    i.trash.icon
    | Delete OAuth Client
  .content
    p
      | Are you sure you want to delete the OAuth client
        <strong class="client-name">[Client Name]</strong>?
        This action cannot be undone and will revoke all
        access tokens for this client.
  .actions
    .ui.red.basic.cancel.inverted.button
      i.remove.icon
      | No
    .ui.green.ok.inverted.button
      i.checkmark.icon
      | Yes
.ui.basic.tiny.delete-oauth-token.modal
  .header
    i.trash.icon
    | Revoke OAuth Token
  .content
    p
      | Are you sure you want to revoke the OAuth token
        <strong class="token-id">[Token ID]</strong>?
        This action cannot be undone and will immediately
        revoke access for this token.
  .actions
    .ui.red.basic.cancel.inverted.button
      i.remove.icon
      | No
    .ui.green.ok.inverted.button
      i.checkmark.icon
      | Yes
