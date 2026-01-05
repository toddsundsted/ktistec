require "../../relationship"
require "../../activity_pub/actor"
require "../../activity_pub/object"

class Relationship
  class Content
    class Bookmark < Relationship
      belongs_to actor, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
      validates(actor) { "missing: #{from_iri}" unless actor? }

      belongs_to object, class_name: ActivityPub::Object, foreign_key: to_iri, primary_key: iri
      validates(object) { "missing: #{to_iri}" unless object? }
    end
  end
end
