require "../task"
require "./mixins/singleton"
require "../feed"

class Task
  # Collection task for orphaned feed state.
  #
  # A feed memoizes its judgments as `Feed::Verdict`s and materializes
  # its membership as `relationships` rows carrying the synthetic
  # `Feed::<id>` type. This task collects both when the object they
  # refer to no longer exists.
  #
  class CollectFeedOrphans < Task
    include Singleton

    Log = ::Log.for(self)

    SWEEP_INTERVAL = 5.minutes

    SWEEP_SIZE = 250

    # The sweep's position.
    #
    class State
      include JSON::Serializable

      property cursor : Int64

      def initialize(@cursor = 0_i64)
      end
    end

    @[Persistent]
    @[Insignificant]
    property state : State { State.new }

    def perform
      Log.debug { "Starting sweep of orphaned feed state" }

      swept_count = collect_orphans

      Log.debug { "Feed orphan sweep completed: deleted #{swept_count} rows" }

      swept_count
    ensure
      self.next_attempt_at = randomized_next_attempt_at(SWEEP_INTERVAL)
    end

    # Deletes the feed state left behind by an object that no longer
    # exists.
    #
    private def collect_orphans
      slice = next_slice
      if slice.empty? && state.cursor > 0
        state.cursor = 0_i64
        slice = next_slice
      end
      return 0 if slice.empty?
      state.cursor = slice.last[0]
      iris = slice.select(&.[2]).map(&.[1]).uniq!
      return 0 if iris.empty?
      feed_ids = Ktistec.database.query_all("SELECT id FROM feeds", as: Int64)
      iris.sum(0) do |iri|
        delete_verdicts(feed_ids, iri) + delete_materialized_rows(iri)
      end
    end

    # Returns the next slice of verdicts.
    #
    private def next_slice
      query = <<-QUERY
        SELECT s.id, s.object_iri,
               NOT EXISTS (SELECT 1 FROM objects o WHERE o.iri = s.object_iri)
          FROM (
            SELECT id, object_iri
              FROM feed_verdicts
             WHERE id > ?
             ORDER BY id
             LIMIT ?
          ) AS s
      QUERY
      Ktistec.database.query_all(query, state.cursor, SWEEP_SIZE, as: {Int64, String, Bool})
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
