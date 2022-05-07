require "../activity"

class ActivityPub::Activity
  class Undo < ActivityPub::Activity
    belongs_to object, class_name: ActivityPub::Activity, foreign_key: object_iri, primary_key: iri

    def validate_model
      errors["activity"] = ["the actor must be the object's actor"] unless actor.iri == object.actor_iri
    end
  end
end
