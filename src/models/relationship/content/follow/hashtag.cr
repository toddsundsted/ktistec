require "../../../relationship"
require "../../../activity_pub/actor"
require "../../../../framework/observable"

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

        OBSERVERS = Ktistec::Observable::Registry(Relationship::Content::Follow::Hashtag).new

        def after_destroy
          Relationship::Content::Follow::Hashtag::OBSERVERS.notify(:destroy, self)
        end
      end
    end
  end
end
