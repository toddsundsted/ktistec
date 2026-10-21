require "../../models/feed"
require "../../models/task/feed/enqueue_backfill"
require "./backend"

class Feed
  # Judge revisions.
  #
  module Revisions
    extend self

    # Moves each feed whose version was judged under an earlier
    # revision of its judge to a version for the current revision,
    # and backfills it if it's published.
    #
    def update : Nil
      ::Feed.all.each do |feed|
        next unless (backend = Backend.find?(feed.backend))
        next if feed.version?.try(&.revision) == backend.revision(feed.params)
        feed.save
        if feed.published?
          ::Task::Feed::EnqueueBackfill.new(owner: feed.owner, feed_id: feed.id.to_s).schedule
        end
      end
    end
  end
end
