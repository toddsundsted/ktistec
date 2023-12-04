require "../../../relationship"
require "../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Reply < Notification
        belongs_to object, class_name: ActivityPub::Object, foreign_key: to_iri, primary_key: iri
        validates(object) { "missing: #{to_iri}" unless object? }
      end
    end
  end
end
