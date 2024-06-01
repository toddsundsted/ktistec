require "../../../relationship"
require "../../../activity_pub/actor"

class Relationship
  class Content
    class Follow
      class Mention < Relationship
        belongs_to actor, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
        validates(actor) { "missing: #{from_iri}" unless actor? }

        # Identifies objects that mention the same entity.
        #
        derived name : String, aliased_to: to_iri
        validates(name) { "must not be blank" if name.blank? }
      end
    end
  end
end
