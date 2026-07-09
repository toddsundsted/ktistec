require "../../models/feed"
require "../../models/feed/verdict"
require "../../rules/feeds"
require "../../rules/maintainer"
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
  end
end
