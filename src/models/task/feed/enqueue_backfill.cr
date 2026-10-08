require "../../task"
require "../../feed"
require "../../activity_pub/actor"
require "../../../services/feed/queue"

class Task
  # Enqueues a published feed's backfill.
  #
  class Feed::EnqueueBackfill < Task
    include ConcurrentTask

    Log = ::Log.for(self)

    belongs_to owner, class_name: ActivityPub::Actor, foreign_key: source_iri, primary_key: iri

    derived feed_id : String, aliased_to: subject_iri

    # Returns the feed being backfilled, or `nil` if it's gone.
    #
    def feed? : ::Feed?
      feed_id.to_i64?.try { |id| ::Feed.find?(id) }
    end

    def perform
      if (feed = feed?)
        ::Feed::Queue.enqueue_backfill(feed)
      else
        Log.debug { "feed #{feed_id} is gone -- not enqueued" }
      end
    end
  end
end
