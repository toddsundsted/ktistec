require "../task"
require "../feed"
require "../../services/feed/judging"
require "../../utils/paths"

class Task
  # Backfills a feed with posts that match its criteria.
  #
  class BackfillFeed < Task
    Log = ::Log.for(self)

    BATCH_SIZE = 250

    BATCH_INTERVAL = 5.seconds

    private EXISTS_QUERY = "subject_iri = ? AND complete = 0 AND backtrace IS NULL"

    # The backfill's progress.
    #
    class State
      include JSON::Serializable

      property cursor : Int64?

      property scanned : Int32

      property included : Int32

      property batches : Int32

      def initialize(@cursor = nil, @scanned = 0, @included = 0, @batches = 0)
      end
    end

    @[Persistent]
    @[Insignificant]
    property state : State { State.new }

    # Returns the IRI that identifies a feed's backfill.
    #
    def self.iri_for(feed : ::Feed) : String
      "#{Ktistec.host}#{Utils::Paths.actor_feed_path(feed.owner, feed)}"
    end

    # Returns whether a backfill exists and is not complete.
    #
    def self.exists?(iri) : Bool
      !where(EXISTS_QUERY, iri).empty?
    end

    # Schedules a backfill for a feed.
    #
    def self.schedule_for(feed : ::Feed) : self?
      return unless feed.floor
      return if feed.draft
      iri = iri_for(feed)
      return if exists?(iri)
      task = new(source_iri: feed.owner_iri.not_nil!, subject_iri: iri)
      task.schedule
      task
    end

    # Destroys a feed's backfill.
    #
    def self.destroy_for(feed : ::Feed) : Nil
      where(subject_iri: iri_for(feed)).each(&.destroy)
    end

    # Returns the feed being backfilled, or `nil` if it's gone.
    #
    def feed? : ::Feed?
      if (id = subject_iri.split("/").last?.try(&.to_i64?))
        ::Feed.find?(id)
      end
    end

    def perform(batch_size = BATCH_SIZE)
      unless (feed = feed?)
        Log.debug { "BackfillFeed: #{subject_iri} is gone -- stopping" }
        return
      end
      # a feed superseded by an edit is destroyed, so "the feed still
      # exists" is the cancellation token. a feed orphaned by a failed
      # publish transition exists but is a draft, and is invisible, so
      # it isn't backfilled either.
      if feed.draft
        Log.debug { "BackfillFeed: #{subject_iri} is a draft -- stopping" }
        return
      end
      unless (floor = feed.floor)
        Log.debug { "BackfillFeed: #{subject_iri} has no floor -- stopping" }
        return
      end

      started = Time.instant
      batch = ::Feed::Judging.backfill(feed, floor, state.cursor, batch_size)
      elapsed = Time.instant - started

      state.scanned += batch.scanned
      state.included += batch.included
      state.batches += 1
      state.cursor = batch.cursor

      if batch.done
        Log.info { "BackfillFeed: #{subject_iri} reached floor #{floor}: batches=#{state.batches} scanned=#{state.scanned} included=#{state.included}" }
        return
      end

      Log.debug { "BackfillFeed: #{subject_iri} batch #{state.batches}: floor=#{floor} cursor=#{state.cursor} scanned=#{batch.scanned} included=#{batch.included} elapsed=#{elapsed.total_milliseconds.round}ms" }

      self.next_attempt_at = BATCH_INTERVAL.from_now
    end
  end
end
