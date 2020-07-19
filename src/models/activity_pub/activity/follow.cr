require "../activity"

class ActivityPub::Activity
  class Follow < ActivityPub::Activity
    belongs_to actor, class_name: ActivityPub::Actor, foreign_key: actor_iri, primary_key: iri
    belongs_to object, class_name: ActivityPub::Actor, foreign_key: object_iri, primary_key: iri

    def valid_for_send?
      valid?
      messages = [] of String
      messages << "actor must be local" unless actor?.try(&.local)
      messages << "object must have an inbox" unless object?.try(&.inbox)
      unless messages.empty?
        errors["activity"] = errors["activity"]? ? errors["activity"] + messages : messages
      end
      errors.empty?
    end
  end
end
