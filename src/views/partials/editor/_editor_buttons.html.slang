- if object.new_record? || object.draft?
  .ui.buttons
    - if object.in_reply_to_iri
      button.ui.primary.button data-has-content-target="button" type="submit" formaction=outbox_path(actor)
        | Send Reply
    - else
      button.ui.primary.button data-has-content-target="button" type="submit" formaction=outbox_path(actor)
        | Publish Post
    - if object.new_record?
      button.ui.button data-has-content-target="button saveDraftButton" type="submit" formaction=objects_path
        | Create Draft
    - else
      button.ui.button data-has-content-target="button saveDraftButton" type="submit" formaction=object_path(object)
        | Update Draft
  - unless object.new_record?
    a.ui.teal.right.floated.button href=actor_relationships_path(actor, "drafts")
      | To Drafts
- else
  button.ui.primary.button data-has-content-target="button" type="submit" formaction=outbox_path(actor)
    | Update Post
