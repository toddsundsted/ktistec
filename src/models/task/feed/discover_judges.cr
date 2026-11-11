require "../../task"
require "../mixins/singleton"
require "../../../services/feed/judges"

class Task
  # Discovers executable judges.
  #
  class Feed::DiscoverJudges < Task
    include Singleton

    # Interval between scans.
    #
    SCAN_INTERVAL = 10.minutes

    def perform
      ::Feed::Judges.scan
    ensure
      self.next_attempt_at = randomized_next_attempt_at(SCAN_INTERVAL)
    end
  end
end
