require "../../relationship"

class Relationship
  class Social
    class Follow < Relationship
      belongs_to actor, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
      validates(actor) { "missing: #{from_iri}" unless actor? }

      belongs_to object, class_name: ActivityPub::Actor, foreign_key: to_iri, primary_key: iri
      validates(object) { "missing: #{to_iri}" unless object? }
    end
  end
end
