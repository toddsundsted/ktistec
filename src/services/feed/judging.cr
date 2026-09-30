require "../../models/feed"
require "../../models/feed/verdict"
require "../../rules/feeds"
require "../../rules/maintainer"
require "../../rules/view/feed"
require "./backend"
require "./candidates"

class Feed
  # The synchronous judging entrypoint.
  #
  # Given a feed: fetch its candidates, judge them via the feed's
  # backend, write verdicts, and after each write explicitly reconcile
  # the feed's view for that object.
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
      view = Rules::Feeds.view_for(feed)
      candidates = Candidates.candidates_for(feed, limit: limit)
      matches = 0
      scanned = 0
      candidates.each do |object|
        break if match_limit && matches >= match_limit
        answer = ask(backend, feed, object)
        write_verdict(feed, object, answer)
        Rules::Maintainer.reconcile_object_for(view, object.iri)
        matches += 1 if included?(answer)
        scanned += 1
      end
      scanned
    end

    # Re-judges the objects a feed currently contains under another
    # feed's criteria, seeding the survivors into the target feed.
    #
    # Used at the publish transition so editing a feed's criteria no
    # longer discards its accumulated contents.
    #
    # Returns the number of survivors seeded.
    #
    def rejudge_contents(source : ::Feed, target : ::Feed) : Int32
      unless (backend = Backend.find?(target.backend))
        raise "is not a registered backend: #{target.backend}"
      end
      return 0 if source.version_id == target.version_id
      view = Rules::Feeds.view_for(target)
      seeded = 0
      Verdict.where(version_id: source.version_id, included: true).each do |verdict|
        next unless (object = verdict.object?)
        next unless Candidates.arrival_for(target, object)
        answer = ask(backend, target, object)
        write_verdict(target, object, answer)
        Rules::Maintainer.reconcile_object_for(view, object.iri)
        seeded += 1 if included?(answer)
      end
      seeded
    end

    # The result of one backfill batch.
    #
    # `cursor` is the object id to resume below. `done` reports that
    # the scan has reached the feed's floor.
    #
    record Batch, scanned : Int32, included : Int32, cursor : Int64?, done : Bool

    # Judges one batch of a feed's unjudged candidates, newest first.
    #
    def backfill(feed : ::Feed, cursor : Int64?, limit : Int32, floor_id : Int64? = nil) : Batch
      unless (backend = Backend.find?(feed.backend))
        raise "is not a registered backend: #{feed.backend}"
      end
      view = Rules::Feeds.view_for(feed)
      candidates = Candidates.candidates_for(feed, cursor, limit, floor_id)
      included = 0
      candidates.each do |object|
        answer = ask(backend, feed, object)
        write_verdict(feed, object, answer)
        if included?(answer)
          Rules::Maintainer.reconcile_object_for(view, object.iri)
          included += 1
        end
      end
      # the scan never leaves the feed's window, so a short batch
      # means no unjudged candidates remain.
      Batch.new(
        scanned: candidates.size,
        included: included,
        cursor: candidates.last?.try(&.id),
        done: candidates.size < limit,
      )
    end

    # Judges a single object against every registered feed, writing
    # (or refreshing) each feed's verdict.
    #
    def judge_arrival(object : ActivityPub::Object) : Nil
      judged = Set(Int64?).new
      Rules::View.registry.each do |view|
        next unless view.is_a?(Rules::View::Feed)
        next unless (feed = ::Feed.find?(view.feed_id))
        next unless (backend = Backend.find?(feed.backend))
        next unless Candidates.arrival_for(feed, object)
        next unless judged.add?(feed.version_id)
        write_verdict(feed, object, ask(backend, feed, object))
      end
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

    private def included?(answer : Backend::Judgment | Failure) : Bool
      answer.is_a?(Backend::Judgment) && answer.included
    end

    private def write_verdict(feed, object, answer : Backend::Judgment | Failure)
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
    end
  end
end
