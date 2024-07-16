require "../../relationship"
require "../../activity_pub/activity"
require "../../activity_pub/actor"

class Relationship
  class Content
    abstract class Notification < Relationship
      belongs_to owner, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
      validates(owner) { "missing: #{from_iri}" unless owner? }

      property confirmed : Bool { true }

      def after_save
        Ktistec::Topic{"/actors/#{owner.username}/notifications"}.notify_subscribers
      end
    end
  end
end
