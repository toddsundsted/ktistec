require "../../../relationship"
require "../../../activity_pub/actor"

class Relationship
  class Content
    class Follow
      class Thread < Relationship
        belongs_to actor, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
        validates(actor) { "missing: #{from_iri}" unless actor? }

        # Identifies objects that are part of a thread.
        #
        # Has the form of an IRI but is not meant to be directly
        # dereferenceable.
        #
        derived thread : String, aliased_to: to_iri
        validates(thread) { "must not be blank" if thread.blank? }
      end
    end
  end
end
