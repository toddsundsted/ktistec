require "../activity"
require "../actor"
require "../object"

class ActivityPub::Activity
  class Delete < ActivityPub::Activity
    belongs_to actor, class_name: ActivityPub::Actor, foreign_key: actor_iri, primary_key: iri
    belongs_to object, class_name: ActivityPub::Object | ActivityPub::Actor, foreign_key: object_iri, primary_key: iri

    def validate(**options)
      super
      unless object.deleted?
        case (_object = object)
        when ActivityPub::Object
          errors["activity"] = ["the actor must be the object's actor"] unless actor == _object.attributed_to
        when ActivityPub::Actor
          errors["activity"] = ["the actors must match"] unless actor == _object
        end
      end
      errors
    end
  end
end
