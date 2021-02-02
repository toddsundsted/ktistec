require "../tag"
require "../activity_pub/actor"
require "../activity_pub/object"

class Tag
  class Hashtag < Tag
    belongs_to subject, class_name: ActivityPub::Object | ActivityPub::Actor, foreign_key: subject_iri, primary_key: iri
    validates(subject) { "missing: #{subject_iri}" unless subject? }
  end
end
