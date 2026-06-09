require "../tag"
require "../activity_pub/actor"
require "../activity_pub/object"
require "../../framework/topic"

class Tag
  class Mention < Tag
    belongs_to subject, class_name: ActivityPub::Object, foreign_key: subject_iri, primary_key: iri
    validates(subject) { "missing: #{subject_iri}" unless subject? }

    validates(name) { "is blank" if name.blank? }

    def before_save
      self.name = self.name.lstrip("@")
      # The host part of a handle is not always present. If it is
      # missing, use the host part of the mention's `href` property.
      unless self.name.includes?("@")
        if (href = self.href) && (host = URI.parse(href).host)
          self.name += "@#{host}"
        end
      end
    end

    def after_create
      Ktistec::Topic{"/mentions/#{name}"}.notify_subscribers(subject.id.to_s)
      super unless subject.draft?
    end

    def after_destroy
      super unless subject.draft?
    end

    # Returns the most recent object with the given mention.
    #
    # Orders objects by `id` as an acceptable proxy for "most recent".
    # (This prevents the query from using a temporary b-tree for
    # ordering).
    #
    # Includes private (not visible) objects.
    #
    def self.most_recent_object(href)
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = '#{self}'
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.href = ?
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "a")}
      ORDER BY t.id DESC
         LIMIT 1
      QUERY
      ActivityPub::Object.query_all(query, href).first?
    end

    # Returns the maximum tag `t.id` for the given object id,
    # restricted to objects tagged with the given mention href. Used
    # to translate the externally-supplied object id into the internal
    # object id. Returns nil for unknown ids or ids of objects that
    # wouldn't appear in the result set.
    #
    private def self.translate_object_id_to_tag_id(href : String, o_id : Int64) : Int64?
      query = <<-QUERY
        SELECT MAX(t.id)
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = '#{self}'
           AND t.href = ?
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE o.id = ?
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "a")}
      QUERY
      ActivityPub::Object.scalar(query, href, o_id).as(Int64?)
    end

    # Returns the objects with the given mention.
    #
    # Includes private (not visible) objects.
    #
    # Orders objects by `id` for consistency with the query above.
    #
    def self.all_objects(href, *, max_id = nil, min_id = nil, limit = 10)
      max_id = translate_object_id_to_tag_id(href, max_id) if max_id
      min_id = translate_object_id_to_tag_id(href, min_id) if min_id
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = '#{self}'
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.href = ?
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "a")}
           AND NOT EXISTS (
             SELECT 1 FROM tags AS t2
              WHERE t2.type = '#{self}'
                AND t2.href = t.href
                AND t2.subject_iri = t.subject_iri
                AND t2.id > t.id
           )
           AND %{cursor_condition}
      QUERY
      ActivityPub::Object.query_with_cursor(query, href, cursor_column: "t.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Returns the count of objects with the given mention since the
    # given time.
    #
    # Uses the same filters as `all_objects(href, max_id, min_id, limit)` but adds
    # a time-based filter on the tag's `created_at` timestamp.
    #
    # Includes private (not visible) objects for consistency.
    #
    def self.all_objects(href, since : Time)
      query = <<-QUERY
        SELECT count(*)
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = '#{self}'
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.href = ?
           AND o.published IS NOT NULL
           #{common_filters(objects: "o", actors: "a")}
           AND t.created_at > ?
      QUERY
      ActivityPub::Object.scalar(query, href, since).as(Int64)
    end

    # Returns the count of objects with the given mention.
    #
    # Uses the statistics table since there is no high cardinality way to
    # subset and count the objects with a given mention.
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

    # Resolves a qualified handle (`user@host`) to its identifying
    # `href`.
    #
    # The inverse of `dominant_name`.
    #
    def self.dominant_href(handle : String) : String?
      query = <<-QUERY
          SELECT href
            FROM tags
           WHERE type = '#{self}'
             AND name = ?
             AND href IS NOT NULL
        GROUP BY href
        ORDER BY count(*) DESC, href ASC
           LIMIT 1
      QUERY
      Ktistec.database.query_one?(query, handle, as: String)
    end

    # Resolves an identifying `href` to its dominant mention name
    # (`user@host`).
    #
    # The inverse of `dominant_href`.
    #
    def self.dominant_name(href : String) : String?
      query = <<-QUERY
          SELECT name
            FROM tags
           WHERE type = '#{self}'
             AND href = ?
             AND name IS NOT NULL
        GROUP BY name
        ORDER BY count(*) DESC, name ASC
           LIMIT 1
      QUERY
      Ktistec.database.query_one?(query, href, as: String)
    end

    # Resolves an identifying `href` to a display handle (`user@host`).
    #
    def self.display_handle(href : String) : String
      ActivityPub::Actor.find?(iri: href).try(&.handle) || dominant_name(href) || href
    end

    # Returns the distinct resolvable qualified handles (`user@host`)
    # for the given `username`.
    #
    def self.qualified_handles(username : String) : Array(String)
      query = <<-QUERY
        SELECT DISTINCT name
          FROM tags
         WHERE type = '#{self}'
           AND name LIKE ? ESCAPE '\\'
           AND href IS NOT NULL
      QUERY
      escaped = username.gsub("%", "\\%").gsub("_", "\\_")
      Ktistec.database.query_all(query, "#{escaped}@%", as: String)
    end
  end
end
