require "../task"
require "./mixins/singleton"
require "../feed"

class Task
  # Collection task for orphaned feed state.
  #
  # A feed memoizes its judgments as `Feed::Verdict`s and materializes
  # its membership as `relationships` rows carrying the synthetic
  # `Feed::<id>` type. This task collects both when the object or
  # actor is deleted.
  #
  class CollectFeedOrphans < Task
    include Singleton

    Log = ::Log.for(self)

    SWEEP_INTERVAL = 5.minutes

    SWEEP_OVERLAP = 1.minute

    SWEEP_LOOKBACK = 2.weeks

    def perform
      Log.debug { "Starting sweep of orphaned feed state" }

      swept_count = collect_orphans

      Log.debug { "Feed orphan sweep completed: deleted #{swept_count} rows" }

      swept_count
    ensure
      self.next_attempt_at = randomized_next_attempt_at(SWEEP_INTERVAL)
    end

    # Deletes the feed state left behind by a deleted object or actor.
    #
    # Only rows deleted since the previous run are considered.
    #
    private def collect_orphans
      iris = deleted_object_iris
      return 0 if iris.empty?
      feed_ids = Ktistec.database.query_all("SELECT id FROM feeds", as: Int64)
      iris.sum(0) do |iri|
        delete_verdicts(feed_ids, iri) + delete_materialized_rows(iri)
      end
    end

    # Returns the IRIs of objects deleted since the previous run.
    #
    private def deleted_object_iris
      since = (last_attempt_at || created_at - SWEEP_LOOKBACK) - SWEEP_OVERLAP
      query = <<-QUERY
        SELECT iri FROM objects WHERE deleted_at > ?
        UNION
        SELECT o.iri
          FROM objects o
          JOIN actors c
            ON c.iri = o.attributed_to_iri
         WHERE c.deleted_at > ?
      QUERY
      Ktistec.database.query_all(query, since, since, as: String)
    end

    # deleting in SQL bypasses model hooks -- if the associated models
    # ever gain any, this and `Feed#delete_verdicts_and_materialized_rows`
    # are the sites to revisit.

    private def delete_verdicts(feed_ids, iri)
      query = "DELETE FROM feed_verdicts WHERE feed_id = ? AND object_iri = ?"
      feed_ids.sum(0) do |feed_id|
        Ktistec.database.exec(query, feed_id, iri).rows_affected.to_i
      end
    end

    private def delete_materialized_rows(iri)
      query = "DELETE FROM relationships WHERE type LIKE 'Feed::%' AND to_iri = ?"
      Ktistec.database.exec(query, iri).rows_affected.to_i
    end
  end
end
