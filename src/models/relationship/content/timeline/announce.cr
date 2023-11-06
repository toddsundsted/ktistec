require "../../../relationship"
require "../timeline"

class Relationship
  class Content
    class Timeline < Relationship
      class Announce < Timeline
      end
    end
  end
end
