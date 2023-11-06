require "../../../relationship"
require "../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Announce < Notification
      end
    end
  end
end
