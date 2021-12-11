require "../activity"
require "../actor"
require "../object"

class ActivityPub::Activity
  class Dislike < ActivityPub::Activity
    belongs_to actor, class_name: ActivityPub::Actor, foreign_key: actor_iri, primary_key: iri
    belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri
  end
end
