require "../tag"
require "../activity_pub/object"

class Tag
  class Hashtag < Tag
    belongs_to subject, class_name: ActivityPub::Object, foreign_key: subject_iri, primary_key: iri
    validates(subject) { "missing: #{subject_iri}" unless subject? }

    # Returns the most recent object with the given hashtag.
    #
    # Orders objects by `id` (not `published`).
    #
    # Includes private (not visible) objects.
    #
    def self.most_recent_object(name)
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
      ORDER BY o.id DESC
         LIMIT 1
      QUERY
      ActivityPub::Object.query_all(query, name).first?
    end

    # Returns the objects with the given hashtag.
    #
    # Includes private (not visible) objects.
    #
    # If `created_after` is specified, only incude objects created
    # after (not published after) that time.
    #
    def self.all_objects(name, page = 1, size = 10, created_after after = Time::UNIX_EPOCH)
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = "#{Tag::Hashtag}"
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.name = ?
           AND o.created_at > ?
           AND o.published IS NOT NULL
           AND o.deleted_at IS NULL
           AND o.blocked_at IS NULL
           AND a.deleted_at IS NULL
           AND a.blocked_at IS NULL
      ORDER BY o.published DESC
         LIMIT ? OFFSET ?
      QUERY
      ActivityPub::Object.query_and_paginate(query, name, after, page: page, size: size)
    end

    # Returns the count of objects with the given hashtag.
    #
    def self.count_all_objects(name, created_after after = Time::UNIX_EPOCH)
      query = <<-QUERY
        SELECT count(*)
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = "#{Tag::Hashtag}"
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.name = ?
           AND o.created_at > ?
           AND o.published IS NOT NULL
           AND o.deleted_at IS NULL
           AND o.blocked_at IS NULL
           AND a.deleted_at IS NULL
           AND a.blocked_at IS NULL
      QUERY
      ActivityPub::Object.scalar(query, name, after).as(Int64)
    end

    # Returns the public objects with the given hashtag.
    #
    # Does not include private (not visible) objects. Includes
    # approved remote objects.
    #
    def self.public_objects(name, page = 1, size = 10)
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
             FROM objects AS o
             JOIN tags AS t
               ON t.subject_iri = o.iri
              AND t.type = "#{Tag::Hashtag}"
             JOIN actors AS a
               ON a.iri = o.attributed_to_iri
        LEFT JOIN relationships AS r
               ON r.to_iri = o.iri
              AND r.type = "#{Relationship::Content::Approved}"
            WHERE t.name = ?
              AND o.visible = 1
              AND (o.iri LIKE "#{Ktistec.host}%" OR r.id)
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

    # Returns the count of public objects with the given hashtag.
    #
    def self.count_public_objects(name)
      query = <<-QUERY
         SELECT count(*)
           FROM objects AS o
           JOIN tags AS t
             ON t.subject_iri = o.iri
            AND t.type = "#{Tag::Hashtag}"
           JOIN actors AS a
             ON a.iri = o.attributed_to_iri
      LEFT JOIN relationships AS r
             ON r.to_iri = o.iri
            AND r.type = "#{Relationship::Content::Approved}"
          WHERE t.name = ?
            AND o.visible = 1
            AND (o.iri LIKE "#{Ktistec.host}%" OR r.id)
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
