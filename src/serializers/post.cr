require "../models/activity_pub/object"

module Serializers
  # A post view-object.
  #
  struct Post
    getter iri : String

    getter content : String?

    def initialize(@iri : String, @content : String?)
    end

    def self.from(object : ActivityPub::Object) : Post
      new(iri: object.iri, content: object.content)
    end
  end
end
