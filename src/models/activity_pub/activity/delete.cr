require "../activity"
require "../actor"
require "../object"

class ActivityPub::Activity
  class Delete < ActivityPub::Activity
    # see: Activity.recursive
    def self.recursive
      false
    end

    belongs_to object, class_name: ActivityPub::Object | ActivityPub::Actor, foreign_key: object_iri, primary_key: iri
  end
end
