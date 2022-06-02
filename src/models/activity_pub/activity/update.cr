require "../activity"
require "../object"

class ActivityPub::Activity
  class Update < ActivityPub::Activity
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
