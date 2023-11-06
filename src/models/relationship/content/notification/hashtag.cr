require "../../../relationship"
require "../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Hashtag < Notification
      end
    end
  end
end
