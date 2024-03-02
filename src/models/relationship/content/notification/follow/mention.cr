require "../../../../relationship"
require "../../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Follow < Notification
        class Mention < Notification
          # Handle of the mentioned actor.
          #
          derived name : String, aliased_to: to_iri
          validates(name) { "must not be blank" if name.blank? }
        end
      end
    end
  end
end
