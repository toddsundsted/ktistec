require "../../task"
require "../mixins/singleton"
require "../../../services/feed/judges"

class Task
  # Discovers executable judges.
  #
  class Feed::DiscoverJudges < Task
    include Singleton

    def perform
      ::Feed::Judges.scan
    ensure
      self.next_attempt_at = 1.minute.from_now
    end
  end
end
