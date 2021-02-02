require "../tag"
require "../activity_pub/actor"

class Tag
  class Mention < Tag
    belongs_to subject, class_name: ActivityPub::Object, foreign_key: subject_iri, primary_key: iri
    validates(subject) { "missing: #{subject_iri}" unless subject? }
  end
end
