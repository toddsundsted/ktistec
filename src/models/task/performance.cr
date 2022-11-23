require "../task"
require "./mixins/singleton"
require "../point"

class Task
  # Captures performance metrics.
  #
  class Performance < Task
    include Singleton

    def perform
      Point.new(
        chart: "total-kilobytes",
        timestamp: Time.utc,
        value: (GC.stats.total_bytes / 1000).to_i32
      ).save
    ensure
      self.next_attempt_at = 1.hour.from_now
    end
  end
end
