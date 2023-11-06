require "../../../relationship"
require "../timeline"

class Relationship
  class Content
    class Timeline < Relationship
      class Create < Timeline
      end
    end
  end
end
