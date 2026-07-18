require "../../models/feed"
require "./judging"

class Feed
  # The preview window.
  #
  # A window is the bounded set of a feed's verdicts produced by
  # previewing a draft. Once a draft's criteria have verdicts they are
  # never recomputed.
  #
  struct Window
    SCAN_CAP  = 100
    MATCH_CAP =  20

    def initialize(@feed : ::Feed)
    end

    # Materializes the window.
    #
    # It is a no-op if the feed already has verdicts.
    #
    def recompute : Int32
      return 0 if computed?
      Feed::Judging.judge(@feed, limit: SCAN_CAP, match_limit: MATCH_CAP)
    end

    # Whether the feed's criteria have been judged, or not.
    #
    private def computed?
      Verdict.count(feed_id: @feed.id) > 0
    end

    # The window's contents.
    #
    def contents(max_id : Int64? = nil, min_id : Int64? = nil, limit : Int32 = MATCH_CAP)
      @feed.contents(max_id: max_id, min_id: min_id, limit: limit)
    end
  end
end
