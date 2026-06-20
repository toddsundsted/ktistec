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
      count = Tag.reconcile_statistics
      Log.debug { "Tag Statistics: Reconciliation complete: #{count} keys" }
    ensure
      self.next_attempt_at = randomized_next_attempt_at(15.minutes)
    end
  end
end
