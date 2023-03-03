require "../tag"
require "../activity_pub/actor"
require "../activity_pub/object"

class Tag
  class Hashtag < Tag
    belongs_to subject, class_name: ActivityPub::Object | ActivityPub::Actor, foreign_key: subject_iri, primary_key: iri
    validates(subject) { "missing: #{subject_iri}" unless subject? }

    def self.all_objects(name, page = 1, size = 10)
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = "#{Tag::Hashtag}"
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.name = ?
           AND o.published IS NOT NULL
           AND o.deleted_at IS NULL
           AND o.blocked_at IS NULL
           AND a.deleted_at IS NULL
           AND a.blocked_at IS NULL
           AND o.id NOT IN (
              SELECT o.id
                FROM objects AS o
                JOIN tags AS t
                  ON t.subject_iri = o.iri
                 AND t.type = "#{Tag::Hashtag}"
                JOIN actors AS a
                  ON a.iri = o.attributed_to_iri
               WHERE t.name = ?
                 AND o.published IS NOT NULL
                 AND o.deleted_at IS NULL
                 AND o.blocked_at IS NULL
                 AND a.deleted_at IS NULL
                 AND a.blocked_at IS NULL
            ORDER BY o.published DESC
               LIMIT ?
           )
      ORDER BY o.published DESC
         LIMIT ?
      QUERY
      ActivityPub::Object.query_and_paginate(query, name, name, page: page, size: size)
    end

    def self.objects_with_tag(name, page = 1, size = 10)
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM objects AS o, tags AS t
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.type = "#{Tag::Hashtag}"
           AND t.subject_iri = o.iri
           AND t.name = ?
           AND o.visible = 1
           AND (o.iri LIKE "#{Ktistec.host}%" OR
                (SELECT id FROM relationships AS r
                 WHERE type = "Relationship::Content::Approved" AND r.to_iri = o.iri))
           AND o.published IS NOT NULL
           AND o.deleted_at IS NULL
           AND o.blocked_at IS NULL
           AND a.deleted_at IS NULL
           AND a.blocked_at IS NULL
           AND o.id NOT IN (
              SELECT o.id
                FROM objects AS o, tags AS t
                JOIN actors AS a
                  ON a.iri = o.attributed_to_iri
               WHERE t.type = "#{Tag::Hashtag}"
                 AND t.subject_iri = o.iri
                 AND t.name = ?
                 AND o.visible = 1
                 AND (o.iri LIKE "#{Ktistec.host}%" OR
                      (SELECT id FROM relationships AS r
                       WHERE type = "Relationship::Content::Approved" AND r.to_iri = o.iri))
                 AND o.published IS NOT NULL
                 AND o.deleted_at IS NULL
                 AND o.blocked_at IS NULL
                 AND a.deleted_at IS NULL
                 AND a.blocked_at IS NULL
            ORDER BY o.published DESC
               LIMIT ?)
      ORDER BY o.published DESC
         LIMIT ?
      QUERY
      ActivityPub::Object.query_and_paginate(query, name, name, page: page, size: size)
    end
  end
end
