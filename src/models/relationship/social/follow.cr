require "../../relationship"
require "../../activity_pub/actor"
require "../../activity_pub/activity/follow"

class Relationship
  class Social
    class Follow < Relationship
      belongs_to actor, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
      validates(actor) { "missing: #{from_iri}" unless actor? }

      belongs_to object, class_name: ActivityPub::Actor, foreign_key: to_iri, primary_key: iri
      validates(object) { "missing: #{to_iri}" unless object? }

      private QUERY = "actor_iri = ? AND object_iri = ? ORDER BY created_at DESC LIMIT 1"

      # Returns the associated follow activity.
      #
      # Returns the most recent associated follow activity if there is
      # more than one.
      #
      # Ignores follow activities that have been undone.
      #
      def activity?
        ActivityPub::Activity::Follow.where(QUERY, from_iri, to_iri).first?
      end
    end
  end
end
