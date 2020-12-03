.ui.basic.tiny.delete.modal
  .header: i.trash.icon
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
