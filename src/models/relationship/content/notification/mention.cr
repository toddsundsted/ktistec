require "../../../relationship"
require "../notification"

class Relationship
  class Content
    class Notification < Relationship
      class Mention < Notification
      end
    end
  end
end
