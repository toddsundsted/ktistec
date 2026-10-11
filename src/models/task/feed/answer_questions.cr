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
      loop do
        batch = ::Feed::Queue.pull
        break if batch.empty?
        answer(batch)
        Fiber.yield
      end
    ensure
      self.next_attempt_at = INTERVAL.from_now
    end

    private def answer(batch)
      reconcile_answer(batch)
    rescue ex
      Log.error { "answering #{batch.size} questions for version #{batch.first.version_id} failed: #{ex.class}: #{ex.message}" }
      failed = true
    ensure
      batch.each do |question|
        ::Feed::Queue.finish(question)
        retry_later(question) if failed
      end
    end

    protected def reconcile_answer(batch : Array(::Feed::Question)) : Nil
      Rules::Trigger.reconcile_for_answer(batch)
    end

    private def retry_later(question)
      ::Feed::Queue.requeue(question.version_id.not_nil!, question.object_iri.not_nil!, live: question.live, due_at: ::Feed::Judging::RETRY_DELAY.from_now)
    end
  end
end
