require "../task"
require "./mixins/singleton"
require "../point"

class Task
  # Captures performance metrics.
  #
  class Performance < Task
    include Singleton

    def perform
      now = Time.utc
      stats = GC.stats
      Point.new(
        chart: "heap-size",
        timestamp: now,
        value: (stats.heap_size / 1000).to_i32
      ).save
      Point.new(
        chart: "free-kilobytes",
        timestamp: now,
        value: (stats.free_bytes / 1000).to_i32
      ).save
      Point.new(
        chart: "total-kilobytes",
        timestamp: now,
        value: (stats.total_bytes / 1000).to_i32
      ).save
    ensure
      self.next_attempt_at = 1.hour.from_now
    end
  end
end
