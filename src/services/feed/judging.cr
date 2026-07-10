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

    # Judges a feed's unjudged candidates.
    #
    # Returns the number of candidates judged.
    #
    def judge(feed : ::Feed, limit : Int32? = nil) : Int32
      unless (backend = Backend.find?(feed.backend))
        raise "is not a registered backend: #{feed.backend}"
      end
      view = Rules::Feeds.view_for(feed)
      candidates = Candidates.candidates_for(feed, limit: limit)
      objects = candidates.map(&.first)
      judgments = backend.judge(feed, objects)
      candidates.zip(judgments) do |(object, arrival), judgment|
        verdict =
          Verdict.find?(feed_id: feed.id, object_iri: object.iri) ||
            Verdict.new(feed: feed, object: object, included: judgment.included, position: arrival)
        verdict.assign(
          included: judgment.included,
          reason: judgment.reason,
          version: feed.version,
          position: arrival,
        ).save
        Rules::Maintainer.reconcile_object_for(view, object.iri)
      end
      candidates.size
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
end
