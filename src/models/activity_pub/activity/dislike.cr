require "../activity"
require "../object"

class ActivityPub::Activity
  class Dislike < ActivityPub::Activity::ObjectActivity
    # see: Activity.recursive
    def self.recursive
      false
    end
  end
end
