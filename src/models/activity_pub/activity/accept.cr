require "../activity"

class ActivityPub::Activity
  class Accept < ActivityPub::Activity
    belongs_to object, class_name: ActivityPub::Activity, foreign_key: object_iri, primary_key: iri
    belongs_to result, class_name: ActivityPub::Object, foreign_key: result_iri, primary_key: iri
  end
end
