require "../activity"
require "../actor"
require "../object"

class ActivityPub::Activity
  class Create < ActivityPub::Activity
    belongs_to actor, class_name: ActivityPub::Actor, foreign_key: actor_iri, primary_key: iri
    belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri

    def valid_for_send?
      valid?
      messages = [] of String
      messages << "actor must be local" unless actor?.try(&.local?)
      messages << "object must be attributed to actor" unless object?.try(&.attributed_to?) == actor?
      unless messages.empty?
        errors["activity"] = errors.fetch("activity", [] of String) + messages
      end
      errors.empty?
    end
  end
end
