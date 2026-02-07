require "../activity"
require "../object"

class ActivityPub::Activity
  class QuoteRequest < ActivityPub::Activity
    # see: Activity.recursive
    def self.recursive
      false
    end

    belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri
    belongs_to instrument, class_name: ActivityPub::Object, foreign_key: instrument_iri, primary_key: iri
  end
end
