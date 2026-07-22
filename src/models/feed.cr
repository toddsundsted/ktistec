require "../framework/model"
require "../framework/model/common"
require "./feed/verdict"
require "../services/feed/backend"

# An algorithmic feed.
#
# A feed is a runtime-created sibling collection to the timeline whose
# membership is decided by a judge rather than by a fixed structural
# rule. The judge's verdicts are the base facts a generic materialized
# view queries.
#
class Feed
  include Ktistec::Model
  include Ktistec::Model::Common

  @@table_name = "feeds"

  @[Persistent]
  property owner_iri : String?
  belongs_to owner, class_name: ActivityPub::Actor, foreign_key: owner_iri, primary_key: iri
  validates(owner) { "missing: #{owner_iri}" unless owner? }

  has_many verdicts, class_name: Feed::Verdict, foreign_key: feed_id, primary_key: id, inverse_of: feed

  @[Persistent]
  property name : String
  validates(name) { "can't be blank" unless name.presence }

  @[Persistent]
  property backend : String
  validates(backend) { "is not a registered backend: #{backend}" unless Backend.find?(backend) }

  @[Persistent]
  property draft : Bool = false

  @[Persistent]
  property copy_of : Int64?
  belongs_to original, class_name: Feed, foreign_key: copy_of, primary_key: id

  @[Persistent]
  property description : String?

  # The arrival time the feed's backfill reaches back to.
  #
  # `nil` means "no backfill".
  #
  @[Persistent]
  property floor : Time?

  # How far back a newly published feed reaches.
  #
  HORIZON = 30.days

  # An example of what belongs in (or doesn't belong in) the feed.
  #
  class Example
    include JSON::Serializable

    property object_iri : String
    property included : Bool

    def initialize(@object_iri : String, @included : Bool)
    end
  end

  @[Persistent]
  property examples : Array(Example) { [] of Example }

  # Backend-owned configuration.
  #
  # Opaque to everything but the backend named by `backend`.
  #
  @[Persistent]
  property params : Hash(String, JSON::Any) { {} of String => JSON::Any }

  # Validates the backend's params.
  #
  # The messages are complete sentences, so they're keyed to no field.
  #
  def validate_model
    if (backend = Backend.find?(self.backend))
      messages = backend.validate_params(params)
      errors[""] = [messages.join(" ")] unless messages.empty?
    end
  end

  # Indicates whether the new criteria differ from the persisted criteria.
  #
  def criteria_changed? : Bool
    return false if new_record?
    # compare against the database row rather than relying on change
    # tracking, so every mutation path is seen
    Feed.find(id).params != params
  end

  # Invalidates the feed's verdicts when the criteria change.
  #
  def before_update
    delete_verdicts_and_materialized_rows if criteria_changed?
  end

  # Invalidates the feed's verdicts when the feed is destroyed.
  #
  def before_destroy
    delete_verdicts_and_materialized_rows
  end

  # Publishes a draft feed.
  #
  def publish
    assign(draft: false, copy_of: nil).save
  end

  # Returns `true` if the feed is published, `false` if it's a draft.
  #
  def published?
    !draft
  end

  # The relationship type of the feed's materialized rows.
  #
  # A synthetic, per-feed string, namespaced so it can never collide
  # with the `Relationship::**` class names. Rows carrying it must
  # never pass through `Relationship`'s polymorphic loader.
  #
  def feed_type : String
    "Feed::#{id.not_nil!}"
  end

  # The size of a feed and the arrival time of its newest post.
  #
  record Stats, count : Int64, newest : Time?

  # Returns the size of the feed and the arrival time of its newest post.
  #
  # Counts only posts the feed displays using the same objects/actors
  # filters `#contents` applies.
  #
  def stats : Stats
    query = <<-QUERY
        SELECT COUNT(*), MAX(f.created_at)
          FROM relationships AS f INDEXED BY idx_relationships_from_iri_type
          JOIN objects AS o
            ON o.iri = f.to_iri
          JOIN actors AS c
            ON c.iri = o.attributed_to_iri
         WHERE f.from_iri = ?
           AND f.type = ?
           #{ActivityPub.common_filters(objects: "o", actors: "c")}
    QUERY
    count, newest = Ktistec.database.query_one(query, owner_iri, feed_type, as: {Int64, Time?})
    Stats.new(count, newest)
  end

  # Deletes the feed's verdicts and materialized rows.
  #
  # The materialized rows carry the synthetic feed `type` and must
  # never pass through `Relationship`'s polymorphic loader.
  #
  # Deleting in SQL bypasses model hooks. If the associated models
  # ever gain any, this and the methods in `Task::CollectFeedOrphans`
  # are the sites to revisit.
  #
  private def delete_verdicts_and_materialized_rows
    Ktistec.database.exec("DELETE FROM feed_verdicts WHERE feed_id = ?", id)
    Ktistec.database.exec("DELETE FROM relationships WHERE from_iri = ? AND type = ?", owner_iri, feed_type)
  end

  # Translates an `Object.id` (external cursor) into the feed row's
  # `(created_at, id)` cursor pair. Returns nil for unknown ids or ids
  # of objects that wouldn't appear in the collection.
  #
  private def translate_object_id_to_feed_created_at_and_id(o_id : Int64) : {Time, Int64}?
    query = <<-QUERY
      SELECT f.created_at, f.id
        FROM relationships AS f
        JOIN objects AS o
          ON o.iri = f.to_iri
        JOIN actors AS c
          ON c.iri = o.attributed_to_iri
       WHERE f.from_iri = ?
         AND f.type = ?
         AND o.id = ?
         #{ActivityPub.common_filters(objects: "o", actors: "c")}
       ORDER BY f.id DESC
       LIMIT 1
    QUERY
    Ktistec.database.query_one?(query, owner_iri, feed_type, o_id, as: {Time, Int64})
  end

  # Returns the objects in the feed, most recently arrived first.
  #
  def contents(max_id : Int64? = nil, min_id : Int64? = nil, limit : Int32 = 10)
    max_cursor = translate_object_id_to_feed_created_at_and_id(max_id) if max_id
    min_cursor = translate_object_id_to_feed_created_at_and_id(min_id) if min_id
    # the pinned index is the only one with a `(from_iri, type)`
    # equality prefix; the broader composites over `created_at` were
    # dropped because they regressed other queries' plans, and the
    # timeline's `(from_iri, created_at)` index is partial over the
    # timeline types.
    query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM relationships AS f INDEXED BY idx_relationships_from_iri_type
          JOIN objects AS o
            ON o.iri = f.to_iri
          JOIN actors AS c
            ON c.iri = o.attributed_to_iri
         WHERE f.from_iri = ?
           AND f.type = ?
           #{ActivityPub.common_filters(objects: "o", actors: "c")}
           AND %{cursor_condition}
    QUERY
    ActivityPub::Object.query_with_keyset_cursor(query, owner_iri, feed_type, cursor_columns: {"f.created_at", "f.id"}, max_cursor: max_cursor, min_cursor: min_cursor, limit: limit)
  end
end
