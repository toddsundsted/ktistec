require "../../models/feed"
require "../../models/feed/question"
require "../../models/feed/verdict"
require "./backend"
require "./candidates"
require "./queue"

class Feed
  # Judging.
  #
  # Given a question from the queue: ask the judge and write the
  # verdict.
  #
  module Judging
    extend self

    Log = ::Log.for(self)

    # Answers a question from the queue.
    #
    def answer(question : Question) : Nil
      return unless (version_id = question.version_id)
      return unless (object = ActivityPub::Object.find?(iri: question.object_iri))
      feeds = ::Feed.where(version_id: version_id)
      return unless (feed = feeds.find { |each| Candidates.arrival_for(each, object) })
      return unless (backend = Backend.find?(feed.backend))
      answer = ask(backend, feed, object)
      # the version may have been abandoned while the judge answered
      return if ::Feed.count(version_id: version_id) == 0
      write_verdict(feed, object, answer, live: question.live)
    end

    # A judge's failure to answer.
    #
    private record Failure, failure : String, reason : String?

    # Asks the judge about an object.
    #
    private def ask(backend, feed, object) : Backend::Judgment | Failure
      backend.judge(feed, [object]).first
    rescue err : Backend::PermanentError
      Log.warn { "judging #{object.iri} for feed #{feed.id} failed (permanent): #{err.message}" }
      Failure.new(Verdict::PERMANENT, err.message)
    rescue err
      Log.warn { "judging #{object.iri} for feed #{feed.id} failed (transient): #{err.message}" }
      Failure.new(Verdict::TRANSIENT, err.message)
    end

    RETRY_DELAY = 5.minutes

    private def write_verdict(feed, object, answer : Backend::Judgment | Failure, live : Bool)
      version_id = feed.version_id
      verdict = Verdict.find?(version_id: version_id, object_iri: object.iri)
      case answer
      in Failure
        included, failure = false, answer.failure
      in Backend::Judgment
        included, failure = answer.included, nil
      end
      verdict ||= Verdict.new(version_id: version_id, object: object, included: included)
      verdict.assign(
        included: included,
        failure: failure,
        reason: answer.reason,
      ).save
      if failure == Verdict::TRANSIENT && version_id
        begin
          Queue.enqueue(version_id, object.iri, live: live, due_at: RETRY_DELAY.from_now)
        rescue err : Queue::FullError
          Log.warn { "not retrying #{object.iri} for version #{version_id}: #{err.message}" }
        end
      end
    end
  end
end
