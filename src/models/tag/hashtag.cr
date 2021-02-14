require "../tag"
require "../activity_pub/actor"
require "../activity_pub/object"

class Tag
  class Hashtag < Tag
    belongs_to subject, class_name: ActivityPub::Object | ActivityPub::Actor, foreign_key: subject_iri, primary_key: iri
    validates(subject) { "missing: #{subject_iri}" unless subject? }

    def self.objects_with_tag(name, page = 1, size = 10)
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM objects AS o
         WHERE EXISTS (
              SELECT 1
                FROM tags AS t
               WHERE t.type = "#{Tag::Hashtag}"
                 AND t.subject_iri = o.iri
                 AND t.name = ?)
           AND o.published IS NOT NULL
           AND o.deleted_at IS NULL
           AND o.visible = 1
           AND o.id NOT IN (
              SELECT o.id
                FROM objects AS o
               WHERE EXISTS (
                    SELECT 1
                      FROM tags AS t
                     WHERE t.type = "#{Tag::Hashtag}"
                       AND t.subject_iri = o.iri
                       AND t.name = ?)
                 AND o.published IS NOT NULL
                 AND o.deleted_at IS NULL
                 AND o.visible = 1
            ORDER BY o.published DESC
               LIMIT ?)
      ORDER BY o.published DESC
         LIMIT ?
      QUERY
      ActivityPub::Object.query_and_paginate(query, name, name, page: page, size: size)
    end
  end
end
