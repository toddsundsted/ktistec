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
  end
end
