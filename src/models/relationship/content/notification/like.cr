require "../../../relationship"
require "../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Like < Notification
      end
    end
  end
end
