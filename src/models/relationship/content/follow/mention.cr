require "../../../relationship"
require "../../../activity_pub/actor"
require "../../../../framework/observable"

class Relationship
  class Content
    class Follow
      class Mention < Relationship
        belongs_to actor, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
        validates(actor) { "missing: #{from_iri}" unless actor? }

        # Identity (`@id`) of the mentioned actor.
        #
        derived href : String, aliased_to: to_iri
        validates(href) { "must not be blank" if href.blank? }

        OBSERVERS = Ktistec::Observable::Registry(Relationship::Content::Follow::Mention).new

        def after_destroy
          Relationship::Content::Follow::Mention::OBSERVERS.notify(:destroy, self)
        end
      end
    end
  end
end
