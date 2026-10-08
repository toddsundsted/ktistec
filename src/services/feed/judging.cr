require "../../models/feed"
require "../../models/feed/question"
require "../../models/feed/verdict"
require "../../rules/feeds"
require "../../rules/maintainer"
require "../../rules/view/feed"
require "./backend"
require "./candidates"
require "./queue"

class Feed
  # The synchronous judging entrypoint.
  #
  # Given a feed: fetch its candidates, judge them via the feed's
  # backend, write verdicts, and after each write explicitly reconcile
  # the views of every feed on the feed's version for that object.
  #
  module Judging
    extend self

    Log = ::Log.for(self)

    # Judges a feed's unjudged candidates, newest first.
    #
    # `limit` caps how many candidates are scanned; `match_limit`
    # stops the scan early once that many matches have been found. A
    # verdict is written for every candidate scanned (included and
    # excluded alike).
    #
    # Returns the number of candidates scanned.
    #
    def judge(feed : ::Feed, limit : Int32? = nil, match_limit : Int32? = nil) : Int32
      unless (backend = Backend.find?(feed.backend))
        raise "is not a registered backend: #{feed.backend}"
      end
      views = views_for(feed)
      candidates = Candidates.candidates_for(feed, limit: limit)
      matches = 0
      scanned = 0
      candidates.each do |object|
        break if match_limit && matches >= match_limit
        answer = ask(backend, feed, object)
        write_verdict(feed, object, answer, live: false)
        reconcile(views, object)
        matches += 1 if included?(answer)
        scanned += 1
      end
      scanned
    end

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

    # Returns the views of every feed on the feed's version.
    #
    private def views_for(feed : ::Feed) : Array(Rules::View::Feed)
      ::Feed.where(version_id: feed.version_id).map { |each| Rules::Feeds.view_for(each) }
    end

    private def reconcile(views : Array(Rules::View::Feed), object : ActivityPub::Object) : Nil
      views.each { |view| Rules::Maintainer.reconcile_object_for(view, object.iri) }
    end

    private def included?(answer : Backend::Judgment | Failure) : Bool
      answer.is_a?(Backend::Judgment) && answer.included
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
