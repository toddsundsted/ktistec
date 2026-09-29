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
        judgment = backend.judge(feed, [object]).first
        write_verdict(feed, object, judgment)
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
      return 0 if source.version_id == target.version_id
      view = Rules::Feeds.view_for(target)
      seeded = 0
      Verdict.where(version_id: source.version_id, included: true).each do |verdict|
        next unless (object = verdict.object?)
        next unless Candidates.arrival_for(target, object)
        judgment = backend.judge(target, [object]).first
        next unless judgment.included
        write_verdict(target, object, judgment)
        Rules::Maintainer.reconcile_object_for(view, object.iri)
        seeded += 1
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
    # Writes a verdict only for posts the feed includes. An excluded
    # post therefore stays a candidate. Skipping excluded verdicts
    # keeps the backfill from writing a row for every post the server
    # has ever held, for every version.
    #
    def backfill(feed : ::Feed, cursor : Int64?, limit : Int32, floor_id : Int64? = nil) : Batch
      unless (backend = Backend.find?(feed.backend))
        raise "is not a registered backend: #{feed.backend}"
      end
      view = Rules::Feeds.view_for(feed)
      candidates = Candidates.candidates_for(feed, cursor, limit, floor_id)
      included = 0
      candidates.each do |object|
        judgment = backend.judge(feed, [object]).first
        if judgment.included
          write_verdict(feed, object, judgment)
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
        judgment = backend.judge(feed, [object]).first
        write_verdict(feed, object, judgment)
      end
    end

    # Writes (or refreshes) the verdict of a feed's version for one
    # object.
    #
    private def write_verdict(feed, object, judgment)
      version_id = feed.version_id
      verdict =
        Verdict.find?(version_id: version_id, object_iri: object.iri) ||
          Verdict.new(version_id: version_id, object: object, included: judgment.included)
      verdict.assign(
        included: judgment.included,
        reason: judgment.reason,
      ).save
    end
  end
end
