require "../../relationship"
require "../../activity_pub/activity"
require "../../activity_pub/activity/create"
require "../../activity_pub/activity/announce"
require "../../activity_pub/activity/like"
require "../../activity_pub/activity/follow"
require "../../activity_pub/actor"

class Relationship
  class Content
    class Notification < Relationship
      belongs_to owner, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
      validates(owner) { "missing: #{from_iri}" unless owner? }

      belongs_to activity, class_name: ActivityPub::Activity, foreign_key: to_iri, primary_key: iri
      validates(activity) { "missing: #{to_iri}" unless activity? }

      property confirmed : Bool { true }

      # Updates the actor's notifications.
      #
      def self.update_notifications(actor, activity)
        case activity
        when ActivityPub::Activity::Create
          if (object = activity.object?)
            unless Notification.find?(from_iri: actor.iri, to_iri: activity.iri) || object.mentions.none? { |mention| mention.href == actor.iri }
              Notification.new(owner: actor, activity: activity).save
            end
          end
        when ActivityPub::Activity::Announce, ActivityPub::Activity::Like
          if (object = activity.object?)
            unless Notification.find?(from_iri: actor.iri, to_iri: activity.iri) || object.attributed_to_iri != actor.iri
              Notification.new(owner: actor, activity: activity).save
            end
          end
        when ActivityPub::Activity::Follow
          if (object = activity.object?)
            unless Notification.find?(from_iri: actor.iri, to_iri: activity.iri) || object != actor
              Notification.new(owner: actor, activity: activity).save
            end
          end
        when ActivityPub::Activity::Delete
          if (object_iri = activity.object_iri) && (create = ActivityPub::Activity::Create.find?(object_iri: object_iri))
            if (notification = can_destroy?(actor.iri, create.iri))
              notification.destroy
            end
          end
        when ActivityPub::Activity::Undo
          if (object_iri = activity.object_iri)
            if (notification = can_destroy?(actor.iri, object_iri))
              notification.destroy
            end
          end
        end
      end

      def self.can_destroy?(actor_iri, activity_iri)
        if (notification = Notification.find?(from_iri: actor_iri, to_iri: activity_iri))
          case notification.activity
          when ActivityPub::Activity::Create
            if ActivityPub::Activity::Delete.find?(object_iri: notification.activity.object_iri)
              notification
            end
          when ActivityPub::Activity::Announce, ActivityPub::Activity::Like, ActivityPub::Activity::Follow
            if ActivityPub::Activity::Undo.find?(object_iri: notification.activity.iri)
              notification
            end
          end
        end
      end
    end
  end
end
