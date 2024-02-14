require "../../../../relationship"
require "../../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Follow < Notification
        class Hashtag < Notification
          # Name of the hashtag.
          #
          derived name : String, aliased_to: to_iri
          validates(name) { "must not be blank" if name.blank? }
        end
      end
    end
  end
end
