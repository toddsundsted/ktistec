require "../../task"
require "../mixins/singleton"
require "../../../services/feed/judging"
require "../../../services/feed/queue"
require "../../../rules/trigger"

class Task
  # Answers the questions in the queue.
  #
  class Feed::AnswerQuestions < Task
    include Singleton
    include ConcurrentTask

    Log = ::Log.for(self)

    # Interval between attempts.
    #
    INTERVAL = 5.seconds

    def perform
      while (question = ::Feed::Queue.pull)
        answer(question)
        Fiber.yield
      end
    ensure
      self.next_attempt_at = INTERVAL.from_now
    end

    private def answer(question)
      reconcile_answer(question)
    rescue ex
      Log.error { "answering #{question.object_iri} for version #{question.version_id} failed: #{ex.class}: #{ex.message}" }
      failed = true
    ensure
      ::Feed::Queue.finish(question)
      retry_later(question) if failed
    end

    protected def reconcile_answer(question : ::Feed::Question) : Nil
      Rules::Trigger.reconcile_for_answer(question)
    end

    private def retry_later(question)
      ::Feed::Queue.enqueue(question.version_id.not_nil!, question.object_iri.not_nil!, live: question.live, due_at: ::Feed::Judging::RETRY_DELAY.from_now)
    rescue err : ::Feed::Queue::FullError
      Log.warn { "not retrying #{question.object_iri} for version #{question.version_id}: #{err.message}" }
    end
  end
end
