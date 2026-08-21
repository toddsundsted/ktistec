- if object.new_record? || object.draft?
  .ui.buttons
    - if object.in_reply_to_iri
      button.ui.primary.button data-has-content-target="button" type="submit" formaction=outbox_path(actor)
        | Send Reply
    - elsif object.quote_iri
      crystal:
        _object = object
        quote_status = _object.responds_to?(:quote_request?) ? _object.quote_request?.try(&.status) : nil
      - if quote_status.nil?
        button.ui.primary.button data-has-content-target="button" type="submit" formaction=quote_path(object.quote)
          | Publish Quote
      - elsif quote_status.authorization_unresolved?
        button.ui.primary.button data-has-content-target="button" type="submit" formaction=verify_quote_path(object)
          | Verify Quote
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
