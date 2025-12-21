require "../../../../relationship"
require "../../notification"
require "../../../../activity_pub/object/question"

class Relationship
  class Content
    class Notification < Relationship
      class Poll < Notification
        class Expiry < Notification
          belongs_to question, class_name: ActivityPub::Object::Question, foreign_key: to_iri, primary_key: iri
          validates(question) { "missing: #{to_iri}" unless question? }
        end
      end
    end
  end
end
