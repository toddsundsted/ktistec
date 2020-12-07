require "../activity"

class ActivityPub::Activity
  class Undo < ActivityPub::Activity
    belongs_to actor, class_name: ActivityPub::Actor, foreign_key: actor_iri, primary_key: iri
    belongs_to object, class_name: ActivityPub::Activity::Follow, foreign_key: object_iri, primary_key: iri

    def validate(**options)
      super
      errors["activity"] = ["the actor must be the object's actor"] unless actor == object.actor
      errors
    end
  end
end
