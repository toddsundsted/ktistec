require "../tag"
require "../activity_pub/object"
require "../relationship/content/public_tagged"
require "../../rules/view/public_tagged"
require "../../framework/topic"

class Tag
  class Hashtag < Tag
    belongs_to subject, class_name: ActivityPub::Object, foreign_key: subject_iri, primary_key: iri
    validates(subject) { "missing: #{subject_iri}" unless subject? }

    validates(name) { "is blank" if name.blank? }

    def before_save
      self.name = self.name.lstrip('#')
    end

    def after_create
      Ktistec::Topic{"/tags/#{name}"}.notify_subscribers(subject.id.to_s)
      super unless subject.draft?
    end

    def after_destroy
      super unless subject.draft?
    end

    # Returns the most recent object with the given hashtag.
    #
    # Orders objects by `id` as an acceptable proxy for "most recent".
    # (This prevents the query from using a temporary b-tree for
    # ordering).
    #
    # Includes private (not visible) objects.
    #
    def self.most_recent_object(name)
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = '#{self}'
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.name = ?
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "a")}
      ORDER BY t.id DESC
         LIMIT 1
      QUERY
      ActivityPub::Object.query_all(query, name).first?
    end

    # Returns the maximum tag `t.id` for the given object id,
    # restricted to objects tagged with the given hashtag name. Used
    # to translate the externally-supplied object id into the internal
    # object id. Returns nil for unknown ids or ids of objects that
    # wouldn't appear in the result set.
    #
    private def self.translate_object_id_to_tag_id(name : String, o_id : Int64) : Int64?
      query = <<-QUERY
        SELECT MAX(t.id)
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = '#{self}'
           AND t.name = ?
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE o.id = ?
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "a")}
      QUERY
      ActivityPub::Object.scalar(query, name, o_id).as(Int64?)
    end

    # Returns the objects with the given hashtag.
    #
    # Includes private (not visible) objects.
    #
    # Orders objects by `id` for consistency with the query above.
    #
    def self.all_objects(name, *, max_id = nil, min_id = nil, limit = 10)
      max_id = translate_object_id_to_tag_id(name, max_id) if max_id
      min_id = translate_object_id_to_tag_id(name, min_id) if min_id
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = '#{self}'
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.name = ?
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "a")}
           AND NOT EXISTS (
             SELECT 1 FROM tags AS t2
              WHERE t2.type = '#{self}'
                AND t2.name = t.name
                AND t2.subject_iri = t.subject_iri
                AND t2.id > t.id
           )
           AND %{cursor_condition}
      QUERY
      ActivityPub::Object.query_with_cursor(query, name, cursor_column: "t.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Returns the count of objects with the given hashtag since the
    # given time.
    #
    # Uses the same filters as `all_objects(name, max_id, min_id, limit)` but adds
    # a time-based filter on the tag's `created_at` timestamp.
    #
    # Includes private (not visible) objects for consistency.
    #
    def self.all_objects(name, since : Time)
      query = <<-QUERY
        SELECT count(*)
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = '#{self}'
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.name = ?
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "a")}
           AND t.created_at > ?
      QUERY
      ActivityPub::Object.scalar(query, name, since).as(Int64)
    end

    # Returns the count of objects with the given hashtag.
    #
    # Uses the statistics table since there is no high cardinality way to
    # subset and count the objects with a given hashtag.
    #
    def self.all_objects_count(name)
      query = <<-QUERY
        SELECT coalesce(sum(count), 0)
          FROM tag_statistics
         WHERE type = ?
           AND name = ?
      QUERY
      ActivityPub::Object.scalar(query, short_type, name).as(Int64)
    end

    # Translates an externally-supplied object id into the
    # `PublicTagged` collection row's `(created_at, id)` cursor pair,
    # scoped to the given hashtag's partition. Returns nil for unknown
    # ids or ids of objects not currently in the collection for this
    # hashtag.
    #
    private def self.translate_object_id_to_public_tagged_cursor(name : String, o_id : Int64) : {Time, Int64}?
      query = <<-QUERY
        SELECT r.created_at, r.id
          FROM relationships AS r
          JOIN objects AS o
            ON o.iri = r.to_iri
         WHERE r.type = '#{Relationship::Content::PublicTagged}'
           AND r.from_iri = #{Rules::View::PublicTagged.from_iri_sql("?")}
           AND o.id = ?
      QUERY
      Ktistec.database.query_one?(query, name, o_id, as: {Time, Int64})
    end

    # Returns the site's public posts with the given hashtag.
    #
    # Does not include private (not visible) posts or
    # replies. Includes other's posts that have been shared.
    #
    def self.public_posts(name, *, max_id = nil, min_id = nil, limit = 10)
      max_cursor = translate_object_id_to_public_tagged_cursor(name, max_id) if max_id
      min_cursor = translate_object_id_to_public_tagged_cursor(name, min_id) if min_id
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM relationships AS r
          JOIN objects AS o
            ON o.iri = r.to_iri
          JOIN actors AS t
            ON t.iri = o.attributed_to_iri
         WHERE r.type = '#{Relationship::Content::PublicTagged}'
           AND r.from_iri = #{Rules::View::PublicTagged.from_iri_sql("?")}
           AND o.visible = 1
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "t")}
           AND %{cursor_condition}
      QUERY
      ActivityPub::Object.query_with_keyset_cursor(query, name, cursor_columns: {"r.created_at", "r.id"}, max_cursor: max_cursor, min_cursor: min_cursor, limit: limit)
    end

    # Returns the count of the site's public posts with the given
    # hashtag.
    #
    # Does not include private (not visible) posts or
    # replies. Includes other's posts that have been shared.
    #
    def self.public_posts_count(name)
      query = <<-QUERY
        SELECT COUNT(*)
          FROM relationships AS r
          JOIN objects AS o
            ON o.iri = r.to_iri
          JOIN actors AS t
            ON t.iri = o.attributed_to_iri
         WHERE r.type = '#{Relationship::Content::PublicTagged}'
           AND r.from_iri = #{Rules::View::PublicTagged.from_iri_sql("?")}
           AND o.visible = 1
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "t")}
      QUERY
      ActivityPub::Object.scalar(query, name).as(Int64)
    end
  end
end
