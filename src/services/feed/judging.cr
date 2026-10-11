require "../../models/feed"
require "../../models/feed/question"
require "../../models/feed/verdict"
require "./backend"
require "./candidates"
require "./queue"

class Feed
  # Judging.
  #
  # Given a batch of questions from the queue: ask the judge and write
  # the verdicts.
  #
  module Judging
    extend self

    Log = ::Log.for(self)

    # Answers a batch of questions from the queue.
    #
    # The questions must all be on one version.
    #
    def answer(batch : Array(Question)) : Nil
      return unless (version_id = batch.first?.try(&.version_id))
      feeds = ::Feed.where(version_id: version_id)
      return unless (feed = feeds.first?)
      return unless (backend = Backend.find?(feed.backend))
      asked = batch.compact_map do |question|
        next unless (object = ActivityPub::Object.find?(iri: question.object_iri))
        next unless feeds.any? { |each| Candidates.arrival_for(each, object) }
        {question, object}
      end
      return if asked.empty?
      answers = ask(backend, feed, asked.map(&.last))
      # the version may have been abandoned while the judge answered
      return if ::Feed.count(version_id: version_id) == 0
      asked.zip(answers) do |(question, object), answer|
        write_verdict(feed, object, answer, live: question.live)
      end
    end

    # Asks the judge about the objects.
    #
    private def ask(backend, feed, objects) : Array(Backend::Judgment | Backend::Failure)
      backend.judge(feed, objects)
    rescue err : Backend::PermanentError
      objects.map { Backend::Failure.new(:permanent, err.message).as(Backend::Judgment | Backend::Failure) }
    rescue err
      objects.map { Backend::Failure.new(:transient, err.message).as(Backend::Judgment | Backend::Failure) }
    end

    RETRY_DELAY = 5.minutes

    private def write_verdict(feed, object, answer : Backend::Judgment | Backend::Failure, live : Bool)
      version_id = feed.version_id
      verdict = Verdict.find?(version_id: version_id, object_iri: object.iri)
      case answer
      in Backend::Failure
        Log.warn { "judging #{object.iri} for feed #{feed.id} failed (#{answer.kind.to_s.downcase}): #{answer.reason}" }
        included = false
        failure =
          case answer.kind
          in .transient? then Verdict::TRANSIENT
          in .permanent? then Verdict::PERMANENT
          end
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
