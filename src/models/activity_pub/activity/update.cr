require "../activity"
require "../actor"
require "../object"

class ActivityPub::Activity
  class Update < ActivityPub::Activity
    belongs_to object, class_name: ActivityPub::Object | ActivityPub::Actor, foreign_key: object_iri, primary_key: iri

    def valid_for_send?
      valid?
      messages = [] of String
      messages << "actor must be local" unless actor?.try(&.local?)
      if (_object = object?).is_a?(ActivityPub::Actor)
        messages << "object must be the actor" unless _object.iri == actor?.try(&.iri)
      else
        messages << "object must be attributed to actor" unless _object.try(&.attributed_to?) == actor?
      end
      unless messages.empty?
        errors["activity"] = errors.fetch("activity", [] of String) + messages
      end
      errors.empty?
    end
  end
end
