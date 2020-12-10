require "../../relationship"
require "../../activity_pub/actor"
require "../../activity_pub/activity"

class Relationship
  class Content
    class Inbox < Relationship
      @@must_be_unique = false

      belongs_to owner, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
      validates(owner) { "missing: #{from_iri}" unless owner? }

      belongs_to activity, class_name: ActivityPub::Activity, foreign_key: to_iri, primary_key: iri
      validates(activity) { "missing: #{to_iri}" unless activity? }

      property confirmed : Bool { true }
    end
  end
end
