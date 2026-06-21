require "../task"
require "../tag"
require "./mixins/singleton"

class Task
  # Reconciles the `tag_statistics` cache.
  #
  class ReconcileTagStatistics < Task
    include Singleton

    Log = ::Log.for(self)

    def perform
      Log.debug { "Tag Statistics: Starting reconciliation" }
      result = Tag.reconcile_statistics
      Log.debug { "Tag Statistics: Reconciliation complete: #{result[:inserted]} inserted, #{result[:updated]} updated, #{result[:zeroed]} zeroed" }
    ensure
      self.next_attempt_at = randomized_next_attempt_at(12.hours)
    end
  end
end
