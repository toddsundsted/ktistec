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
      candidates = Candidates.candidates_for(feed, limit: limit)
      matches = 0
      scanned = 0
      candidates.each do |(object, arrival)|
        break if match_limit && matches >= match_limit
        judgment = backend.judge(feed, [object]).first
        write_verdict(feed, object, arrival, judgment)
        matches += 1 if judgment.included
        scanned += 1
      end
      # rebuild the whole view, not just the scanned objects: a version
      # bump makes every prior-criteria row non-current, and a bounded
      # scan may not re-reach them to drop them incrementally.
      Rules::Maintainer.reconcile(Rules::Feeds.view_for(feed))
      scanned
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
        version: feed.version,
        position: arrival,
      ).save
    end
  end
end
