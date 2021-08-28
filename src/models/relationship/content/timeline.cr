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

      # Updates the actor's timeline.
      #
      # Timeline rules:
      #
      # Generally, an object belongs in an actor's timeline iff
      # 1) there is an outstanding create not countered by a
      # corresponding delete, or 2) there is an outstanding announce
      # not undone by a subsequent undo.
      #
      def self.update_timeline(actor, activity)
        case activity
        when ActivityPub::Activity::Create
          if (object = activity.object?)
            unless Timeline.find?(from_iri: actor.iri, to_iri: object.iri) || object.in_reply_to?
              Timeline.new(owner: actor, object: object).save
            end
          end
        when ActivityPub::Activity::Announce
          if (object = activity.object?)
            unless Timeline.find?(from_iri: actor.iri, to_iri: object.iri)
              Timeline.new(owner: actor, object: object).save
            end
          end
        when ActivityPub::Activity::Delete
          if (object_iri = activity.object_iri)
            if (timeline = can_destroy?(actor.iri, object_iri))
              timeline.destroy
            end
          end
        when ActivityPub::Activity::Undo
          if (activity = activity.object?) && activity.is_a?(ActivityPub::Activity::Announce) && (object_iri = activity.object_iri)
            if (timeline = can_destroy?(actor.iri, object_iri))
              timeline.destroy
            end
          end
        end
      end

      def self.can_destroy?(actor_iri, object_iri)
        if (object = ActivityPub::Object.find?(object_iri))
          activities = object.activities
          counts = activities.reduce(Hash(String, Int64).new(0)) do |counts, activity|
            counts[activity.type] += 1
            counts
          end
          unless unbalanced?(counts)
            Timeline.find?(from_iri: actor_iri, to_iri: object_iri)
          end
        else
          Timeline.find?(from_iri: actor_iri, to_iri: object_iri)
        end
      end

      private def self.unbalanced?(counts)
        # are there any uncountered creates, or any not undone
        # announces? `#activities` does not return undone announces
        # so just look at announces
        (counts["ActivityPub::Activity::Create"] - counts["ActivityPub::Activity::Delete"] > 0) ||
          counts["ActivityPub::Activity::Announce"] > 0
      end
    end
  end
end
