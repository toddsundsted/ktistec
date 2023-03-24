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

        # Merges relationships.
        #
        # Should be used in places where an object's thread property
        # is changed. Ensures that only one relationship exists for a
        # thread.
        #
        def self.merge_into(from, into)
          if from != into
            where(thread: from).each do |follow|
              unless find?(actor: follow.actor, thread: into)
                follow.assign(thread: into).save
              else
                follow.destroy
              end
            end
          end
        end
      end
    end
  end
end
