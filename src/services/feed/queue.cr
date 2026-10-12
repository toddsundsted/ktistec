require "../../models/feed/question"
require "./candidates"

class Feed
  # The judge queue.
  #
  module Queue
    extend self

    Log = ::Log.for(self)

    # The number of candidates read at a time.
    #
    class_property page_size : Int32 = 250

    # The number of questions beyond which backfill is refused.
    #
    class_property backfill_cap : Int32 = 100_000

    # The number of questions beyond which *anything* is refused.
    #
    class_property live_cap : Int32 = 110_000

    # Raised when the queue is full.
    #
    class FullError < Exception
    end

    # Enqueues a question.
    #
    # A question for a pair that is already waiting coalesces into the
    # waiting question.
    #
    # Raises `FullError` if the queue is full.
    #
    def enqueue(version_id : Int64, object_iri : String, live : Bool, due_at : Time = Time.utc) : Nil
      enqueue(version_id, object_iri, live, due_at, cap: live ? live_cap : backfill_cap)
    end

    # Enqueues a question again, to be asked later.
    #
    # The cap does not apply.
    #
    def requeue(version_id : Int64, object_iri : String, live : Bool, due_at : Time) : Nil
      enqueue(version_id, object_iri, live, due_at, cap: nil)
    end

    private def enqueue(version_id : Int64, object_iri : String, live : Bool, due_at : Time, cap : Int32?) : Nil
      if (question = Question.find?(version_id: version_id, object_iri: object_iri, batched: false))
        question.due_at = due_at unless pulled_first?(question, live, due_at, Time.utc)
        question.live ||= live
        question.save
      else
        if cap && Question.count(batched: false) >= cap
          raise FullError.new("queue is full: #{object_iri} for version #{version_id}")
        end
        Question.new(version_id: version_id, object_iri: object_iri, live: live, due_at: due_at).save
      end
    end

    private def pulled_first?(question, live, due_at, now) : Bool
      if question.due_at <= now && due_at <= now
        (question.live && !live) || (question.live == live && question.due_at <= due_at)
      else
        question.due_at <= due_at
      end
    end

    # Enqueues a feed's candidates, newest first.
    #
    # Silently sheds questions if the queue is full.
    #
    def enqueue_backfill(feed : ::Feed, limit : Int32? = nil, live : Bool = false) : Nil
      return unless feed.floor
      version_id = feed.version_id.not_nil!
      version = Version.find(version_id)
      floor_id = Candidates.floor_id(feed) || 0_i64
      remaining = limit
      cursor = version.backfill_cursor
      loop do
        break if remaining && remaining < 1
        size = remaining ? Math.min(page_size, remaining) : page_size
        page = Candidates.candidates_for(feed, cursor, size, floor_id)
        page.each { |object| enqueue(version_id, object.iri, live: live) }
        if (last = page.last?)
          cursor = last.id!
          version.cover_down_to(cursor)
        end
        remaining -= page.size if remaining
        break if page.size < size
      end
    rescue err : FullError
      Log.warn { "backfill of feed #{feed.id} is incomplete: #{err.message}" }
    end

    # Enqueues an object as a live question for every registered
    # feed's version it is a candidate for.
    #
    # Silently sheds the question if the queue is full.
    #
    def enqueue_arrival(object : ActivityPub::Object) : Nil
      Rules::View.registry.each do |view|
        next unless view.is_a?(Rules::View::Feed)
        next unless (feed = ::Feed.find?(view.feed_id))
        next unless (version_id = feed.version_id)
        next unless Candidates.arrival_for(feed, object)
        begin
          enqueue(version_id, object.iri, live: true)
        rescue err : FullError
          Log.warn { "arrival of #{object.iri} for version #{version_id} is not judged: #{err.message}" }
        end
      end
    end

    # Pulls the next batch of questions that are due.
    #
    # The batch is the next question to pull and the questions after
    # it on the same version, up to its judge's batch size.
    #
    def pull(now : Time = Time.utc) : Array(Question)
      return [] of Question unless (version_id = Question.next_version_id(now))
      Question.pull(version_id, batch_size(version_id), now)
    end

    # Returns the batch size the version's judge declares, or 1 if the
    # version or its judge is gone.
    #
    private def batch_size(version_id : Int64) : Int32
      if (version = Version.find?(version_id)) && (backend = Backend.find?(version.backend))
        backend.cost(JSON.parse(version.params).as_h).batch_size
      else
        1
      end
    end

    # Removes an answered question.
    #
    def finish(question : Question) : Nil
      question.destroy
    end

    # Returns every question in a batch to waiting.
    #
    # Each is enqueued again, so duplicates coalesce.
    #
    # The cap does not apply.
    #
    def release_batches : Nil
      Question.where(batched: true).each do |question|
        question.destroy
        enqueue(question.version_id.not_nil!, question.object_iri.not_nil!, question.live, question.due_at, cap: nil)
      end
    end
  end
end
