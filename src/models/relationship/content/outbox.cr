require "../../relationship"

class Relationship
  class Content
    class Outbox < Relationship
      belongs_to owner, class_name: ActivityPub::Actor, foreign_key: from_iri, primary_key: iri
      validates(owner) { "missing: #{from_iri}" unless owner? }

      belongs_to activity, class_name: ActivityPub::Activity, foreign_key: to_iri, primary_key: iri
      validates(activity) { "missing: #{to_iri}" unless activity? }
    end
  end
end
