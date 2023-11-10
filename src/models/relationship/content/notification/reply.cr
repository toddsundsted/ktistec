require "../../../relationship"
require "../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Reply < Notification
      end
    end
  end
end
