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
    end
  end
end
