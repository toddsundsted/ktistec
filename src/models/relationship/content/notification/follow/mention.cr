require "../../../../relationship"
require "../../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Follow < Notification
        class Mention < Notification
          # Identity (`@id`) of the mentioned actor.
          #
          derived href : String, aliased_to: to_iri
          validates(href) { "must not be blank" if href.blank? }
        end
      end
    end
  end
end
