require "./view/feed"
require "../models/feed"

module Rules
  # A feed registration.
  #
  module Feeds
    extend self

    # Returns the view for a feed.
    #
    def view_for(feed : ::Feed) : View::Feed
      View::Feed.new(feed_id: feed.id.not_nil!, owner_iri: feed.owner_iri.not_nil!)
    end

    # Registers a view for every feed.
    #
    def register_all : Nil
      ::Feed.all.each do |feed|
        View.register(view_for(feed))
      end
    end

    # Registers the feed's view.
    #
    def register(feed : ::Feed) : Nil
      View.register(view_for(feed))
    end

    # Unregisters the feed's view.
    #
    def unregister(feed : ::Feed) : Nil
      View.unregister(view_for(feed))
    end
  end
end
