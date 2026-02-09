require "../activity"
require "../object"

class ActivityPub::Activity
  class QuoteRequest < ActivityPub::Activity
    # see: Activity.recursive
    def self.recursive
      false
    end

    # NOTE: per FEP-044F, "The `QuoteRequest` activity uses the
    # `object` property to refer to the quoted object, and the
    # `instrument` property to refer to the quote post."

    belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri
    belongs_to instrument, class_name: ActivityPub::Object, foreign_key: instrument_iri, primary_key: iri
  end
end
