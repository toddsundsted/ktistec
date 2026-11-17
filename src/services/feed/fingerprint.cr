require "../../models/feed"
require "../../models/activity_pub/object"
require "../../serializers/author"
require "../../serializers/feed"
require "../../serializers/post"
require "../../serializers/stats"

class Feed
  # What a judge sees about a post, as a hash of each part.
  #
  record Fingerprint, post : UInt64, author : UInt64, referenced : UInt64, stats : UInt64, feed : UInt64 do
    # Returns the names of the parts that differ from `other`.
    #
    def changes(other : Fingerprint) : Array(String)
      changes = [] of String
      changes << "post" if post != other.post
      changes << "author" if author != other.author
      changes << "referenced" if referenced != other.referenced
      changes << "stats" if stats != other.stats
      changes << "feed" if feed != other.feed
      changes
    end

    # Returns the fingerprints of `objects`, as seen by `feed`'s owner.
    #
    # Stats are computed over windows ending at `now`.
    #
    def self.for(feed : ::Feed, objects : Array(ActivityPub::Object), now : Time = Time.utc) : Array(Fingerprint)
      owner_iri = feed.owner_iri
      stats = Serializers::Stats.from(owner_iri, now).hash
      serialized_feed = Serializers::Feed.from(feed).hash
      objects.map do |object|
        referenced = Serializers::Post.referenced(object).map do |each|
          {Serializers::Post.from(each, owner_iri), author_of(each, owner_iri, now)}
        end
        new(
          post: Serializers::Post.from(object, owner_iri).hash,
          author: author_of(object, owner_iri, now).hash,
          referenced: referenced.hash,
          stats: stats,
          feed: serialized_feed,
        )
      end
    end

    private def self.author_of(object, owner_iri, now) : Serializers::Author?
      object.attributed_to?(include_deleted: true).try { |actor| Serializers::Author.from(actor, owner_iri, now) }
    end
  end
end
