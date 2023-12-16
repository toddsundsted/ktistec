require "../../../relationship"
require "../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Follow < Notification
        belongs_to activity, class_name: ActivityPub::Activity::Follow, foreign_key: to_iri, primary_key: iri
        validates(activity) { "missing: #{to_iri}" unless activity? }
      end
    end
  end
end
