require "json"

require "../models/feed"

module Serializers
  # A feed view-object.
  #
  struct Feed
    getter name : String

    getter description : String?

    getter params : Hash(String, JSON::Any)

    def initialize(@name : String, @description : String?, @params : Hash(String, JSON::Any))
    end

    def self.from(feed : ::Feed) : Feed
      new(name: feed.name, description: feed.description, params: feed.params)
    end
  end
end
