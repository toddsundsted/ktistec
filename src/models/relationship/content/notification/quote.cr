require "../../../relationship"
require "../../../activity_pub/activity/quote_request"
require "../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Quote < Notification
        belongs_to activity, class_name: ActivityPub::Activity::QuoteRequest, foreign_key: to_iri, primary_key: iri
        validates(activity) { "missing: #{to_iri}" unless activity? }
      end
    end
  end
end
