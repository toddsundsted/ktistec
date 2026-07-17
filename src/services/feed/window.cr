require "../../models/feed"
require "../../rules/feeds"
require "../../rules/maintainer"
require "./judging"

class Feed
  # The preview window.
  #
  # A window is the bounded set of a feed's current-version verdicts
  # produced by previewing a draft. Once a version has verdicts they
  # are never recomputed.
  #
  struct Window
    SCAN_CAP  = 100
    MATCH_CAP =  20

    def initialize(@feed : ::Feed)
    end

    # Materializes the window.
    #
    # It is a no-op if the current version already has verdicts.
    #
    def recompute : Int32
      return 0 if computed?
      Feed::Judging.judge(@feed, limit: SCAN_CAP, match_limit: MATCH_CAP)
    end

    # Whether the current version has been judged, or not.
    #
    private def computed?
      Verdict.count(feed_id: @feed.id, version: @feed.version) > 0
    end

    # Commits the window as it stands, without re-judging.
    #
    # Reconciles the feed's view against its current-version
    # verdicts.
    #
    def adopt : Nil
      Rules::Maintainer.reconcile(Rules::Feeds.view_for(@feed))
    end

    # The window's contents.
    #
    def contents(max_id : Int64? = nil, min_id : Int64? = nil, limit : Int32 = MATCH_CAP)
      @feed.contents(max_id: max_id, min_id: min_id, limit: limit)
    end
  end
end
