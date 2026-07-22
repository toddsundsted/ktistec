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
  # Invariant: a judge pass must not yield to another fiber between
  # candidate selection and its last verdict write. A criteria edit
  # deletes the feed's verdicts (see `Feed#before_update`); a verdict
  # written after that delete from a stale in-flight pass would
  # survive as apparently current, and candidates with verdicts are
  # never re-judged.
  #
  module Judging
    extend self

    Log = ::Log.for(self)

    # Judges a feed's unjudged candidates, most recently arrived
    # first.
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
      candidates.each do |(object, arrival)|
        break if match_limit && matches >= match_limit
        judgment = backend.judge(feed, [object]).first
        write_verdict(feed, object, arrival, judgment)
        Rules::Maintainer.reconcile_object_for(view, object.iri)
        matches += 1 if judgment.included
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
      view = Rules::Feeds.view_for(target)
      seeded = 0
      Verdict.where(feed_id: source.id, included: true).each do |verdict|
        next unless (object = verdict.object?)
        judgment = backend.judge(target, [object]).first
        next unless judgment.included
        write_verdict(target, object, verdict.position, judgment)
        Rules::Maintainer.reconcile_object_for(view, object.iri)
        seeded += 1
      end
      seeded
    end

    # The result of one backfill batch.
    #
    # `oldest` is the arrival time of the last candidate judged --
    # the next batch's cursor.
    #
    record Batch, scanned : Int32, included : Int32, oldest : Time?

    # Judges one batch of a feed's unjudged candidates between `floor`
    # and `cursor`, most recently arrived first.
    #
    # Writes a verdict only for candidates the feed includes. An
    # excluded candidate therefore stays a candidate. Skipping
    # excluded verdicts keeps the backfill from writing a row for
    # every post the owner has ever received, for every feed they own.
    #
    def backfill(feed : ::Feed, floor : Time, cursor : Time?, limit : Int32) : Batch
      unless (backend = Backend.find?(feed.backend))
        raise "is not a registered backend: #{feed.backend}"
      end
      view = Rules::Feeds.view_for(feed)
      candidates = Candidates.backfill_candidates_for(feed, floor, cursor, limit)
      included = 0
      oldest = nil
      candidates.each do |(object, arrival)|
        judgment = backend.judge(feed, [object]).first
        if judgment.included
          write_verdict(feed, object, arrival, judgment)
          Rules::Maintainer.reconcile_object_for(view, object.iri)
          included += 1
        end
        oldest = arrival
      end
      Batch.new(scanned: candidates.size, included: included, oldest: oldest)
    end

    # Judges a single newly-arrived object against every registered
    # feed, writing (or refreshing) each feed's verdict.
    #
    def judge_arrival(object : ActivityPub::Object) : Nil
      Rules::View.registry.each do |view|
        next unless view.is_a?(Rules::View::Feed)
        next unless (feed = ::Feed.find?(view.feed_id))
        next unless (backend = Backend.find?(feed.backend))
        next unless (arrival = Candidates.arrival_for(feed, object))
        judgment = backend.judge(feed, [object]).first
        write_verdict(feed, object, arrival, judgment)
      end
    end

    # Writes (or refreshes) a feed's verdict for one object.
    #
    private def write_verdict(feed, object, arrival, judgment)
      verdict =
        Verdict.find?(feed_id: feed.id, object_iri: object.iri) ||
          Verdict.new(feed: feed, object: object, included: judgment.included, position: arrival)
      verdict.assign(
        included: judgment.included,
        reason: judgment.reason,
        position: arrival,
      ).save
    end
  end
end
