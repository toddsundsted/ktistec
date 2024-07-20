require "../../../relationship"
require "../../../activity_pub/actor"

class Relationship
  class Content
    class Follow
      class Hashtag < Relationship
        belongs_to actor, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
        validates(actor) { "missing: #{from_iri}" unless actor? }

        # Identifies a tagged collection of objects.
        #
        derived name : String, aliased_to: to_iri
        validates(name) { "must not be blank" if name.blank? }
      end
    end
  end
end
