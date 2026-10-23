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
      name = feed.backend
      begin
        answers = ask(backend, feed, asked.map(&.last))
      rescue err : Backend::UnavailableError
        pause(name, err.message, err.retry_after)
        asked.each do |(question, _)|
          Queue.requeue(question.version_id.not_nil!, question.object_iri.not_nil!, live: question.live, due_at: question.due_at)
        end
        return
      end
      # the version may have been abandoned while the judge answered
      return if ::Feed.count(version_id: version_id) == 0
      if answers.all? { |answer| answer.is_a?(Backend::Failure) && answer.kind.transient? }
        if failed(name) >= FAILURES_BEFORE_PAUSE
          pause(name, "#{FAILURES_BEFORE_PAUSE} or more batches in a row failed", nil)
        end
      else
        forget(name)
      end
      asked.zip(answers) do |(question, object), answer|
        write_verdict(feed, object, answer, live: question.live)
      end
    end

    # each pause in a row is twice as long as the last, up to `LONGEST_PAUSE`

    PAUSE = 5.minutes

    LONGEST_PAUSE = 1.day

    FAILURES_BEFORE_PAUSE = 3

    # The batches in a row that failed, and the length of the last
    # pause, if any.
    #
    private record Run, failures : Int32 = 0, pause : Time::Span? = nil

    # Runs, by judge name.
    #
    @@runs = {} of String => Run

    # Forgets a judge's run of failures.
    #
    def forget(name : String) : Nil
      @@runs.delete(name)
    end

    # Counts a failed batch.
    #
    private def failed(name : String) : Int32
      run = @@runs[name]? || Run.new
      @@runs[name] = run.copy_with(failures: run.failures + 1)
      run.failures + 1
    end

    # Pauses the judge.
    #
    private def pause(name : String, reason : String?, retry_after : Time?) : Nil
      run = @@runs[name]? || Run.new
      length = (last = run.pause) ? Math.min(last * 2, LONGEST_PAUSE) : PAUSE
      @@runs[name] = run.copy_with(pause: length)
      now = Time.utc
      time = now + length
      if retry_after && now < retry_after < time
        time = retry_after
      end
      Queue.pause(name, until: time)
      Log.warn { "judge #{name} is paused until #{time}: #{reason}" }
    end

    # Asks the judge about the objects.
    #
    private def ask(backend, feed, objects) : Array(Backend::Judgment | Backend::Failure)
      backend.judge(feed, objects)
    rescue err : Backend::UnavailableError
      raise err
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
        unless answer.included
          verdict.try(&.destroy)
          return
        end
        included, failure = true, nil
      end
      verdict ||= Verdict.new(version_id: version_id, object: object, included: included)
      verdict.assign(
        included: included,
        failure: failure,
        reason: answer.reason,
      ).save
      if failure == Verdict::TRANSIENT && version_id
        Queue.requeue(version_id, object.iri, live: live, due_at: RETRY_DELAY.from_now)
      end
    end
  end
end
