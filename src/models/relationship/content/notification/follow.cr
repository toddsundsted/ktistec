require "../../../relationship"
require "../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Follow < Notification
      end
    end
  end
end
