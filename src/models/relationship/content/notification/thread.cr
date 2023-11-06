require "../../../relationship"
require "../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Thread < Notification
      end
    end
  end
end
