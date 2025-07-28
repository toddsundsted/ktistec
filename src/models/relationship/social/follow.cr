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

      private def self.follow_query(direction)
        <<-QUERY
          SELECT #{columns}
            FROM relationships
           WHERE type = '#{self}'
             AND #{direction} = ?
          ORDER BY id DESC
           LIMIT ? OFFSET ?
        QUERY
      end

      # Returns followers.
      #
      # Returns relationships where the actor is being followed (`to_iri`).
      #
      # Results are ordered by most recent first.
      #
      def self.followers_for(actor_iri : String, page = 1, size = 10)
        query = follow_query("to_iri")
        query_and_paginate(query, actor_iri, page: page, size: size)
      end

      # Returns following.
      #
      # Returns relationships where the actor is following others (`from_iri`).
      #
      # Results are ordered by most recent first.
      #
      def self.following_for(actor_iri : String, page = 1, size = 10)
        query = follow_query("from_iri")
        query_and_paginate(query, actor_iri, page: page, size: size)
      end

      # Returns true if the follow relationship has been accepted.
      #
      def accepted?
        if (follow_activity = self.activity?)
          follow_activity.accepted_or_rejected?.is_a?(ActivityPub::Activity::Accept)
        end
      end

      # Returns true if the follow relationship has been rejected.
      #
      def rejected?
        if (follow_activity = self.activity?)
          follow_activity.accepted_or_rejected?.is_a?(ActivityPub::Activity::Reject)
        end
      end

      # Returns true if the follow relationship is pending.
      #
      # A follow is pending if it has not been accepted or rejected
      # (confirmed = false).
      #
      def pending?
        !confirmed
      end
    end
  end
end
