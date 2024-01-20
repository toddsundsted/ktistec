require "../tag"
require "../activity_pub/object"

class Tag
  class Mention < Tag
    belongs_to subject, class_name: ActivityPub::Object, foreign_key: subject_iri, primary_key: iri
    validates(subject) { "missing: #{subject_iri}" unless subject? }

    # Returns the objects with the given mention.
    #
    # Includes private (not visible) objects.
    #
    def self.all_objects(name, page = 1, size = 10)
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = "#{Tag::Mention}"
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.name = ?
           AND o.published IS NOT NULL
           AND o.deleted_at IS NULL
           AND o.blocked_at IS NULL
           AND a.deleted_at IS NULL
           AND a.blocked_at IS NULL
      ORDER BY o.published DESC
         LIMIT ? OFFSET ?
      QUERY
      ActivityPub::Object.query_and_paginate(query, name, page: page, size: size)
    end

    # Returns the count of objects with the given mention.
    #
    def self.count_objects(name)
      query = <<-QUERY
        SELECT count(*)
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = "#{Tag::Mention}"
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.name = ?
           AND o.published IS NOT NULL
           AND o.deleted_at IS NULL
           AND o.blocked_at IS NULL
           AND a.deleted_at IS NULL
           AND a.blocked_at IS NULL
      QUERY
      ActivityPub::Object.scalar(query, name).as(Int64)
    end
  end
end
