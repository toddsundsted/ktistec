require "../../relationship"
require "../../activity_pub/actor"
require "../../activity_pub/object"

class Relationship
  class Content
    class Timeline < Relationship
      belongs_to owner, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
      validates(owner) { "missing: #{from_iri}" unless owner? }

      belongs_to object, class_name: ActivityPub::Object, foreign_key: to_iri, primary_key: iri
      validates(object) { "missing: #{to_iri}" unless object? }

      property confirmed : Bool { true }
    end
  end
end
