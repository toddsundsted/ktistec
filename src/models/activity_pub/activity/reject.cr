require "../activity"
require "./follow"

class ActivityPub::Activity
  class Reject < ActivityPub::Activity
    belongs_to object, class_name: ActivityPub::Activity::Follow, foreign_key: object_iri, primary_key: iri
  end
end
