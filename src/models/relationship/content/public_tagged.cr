require "../../relationship"
require "../../activity_pub/object"

class Relationship
  class Content
    # Public hashtag feed.
    #
    # `PublicTagged` is the intersection of the `PublicTimeline` and the
    # hashtags applied to its members: one row per `(tag, object)`. It
    # is global and not owned by any actor, so `from_iri` is a synthetic
    # host-qualified hashtag IRI (the tag's identity).
    #
    class PublicTagged < Relationship
      belongs_to object, class_name: ActivityPub::Object, foreign_key: to_iri, primary_key: iri
      validates(object) { "missing: #{to_iri}" unless object? }
    end
  end
end
