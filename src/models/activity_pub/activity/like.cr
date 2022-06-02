require "../activity"
require "../object"

class ActivityPub::Activity
  class Like < ActivityPub::Activity
    belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri
  end
end
