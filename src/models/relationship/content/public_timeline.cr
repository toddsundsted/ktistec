require "../../relationship"
require "../../activity_pub/object"
require "../../../ktistec/constants"

class Relationship
  class Content
    # Public timeline.
    #
    # The public timeline is global and not owned by any actor, so
    # every instance uses the ActivityStreams Public URI as a uniform
    # sentinel `from_iri`.
    #
    class PublicTimeline < Relationship
      @from_iri : String = Ktistec::Constants::PUBLIC

      belongs_to object, class_name: ActivityPub::Object, foreign_key: to_iri, primary_key: iri
      validates(object) { "missing: #{to_iri}" unless object? }
    end
  end
end
