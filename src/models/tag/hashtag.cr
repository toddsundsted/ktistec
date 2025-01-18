require "../tag"
require "../activity_pub/object"
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
    end

    def after_save
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
           AND t.type = "#{self}"
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.name = ?
           AND o.published IS NOT NULL
           AND o.deleted_at IS NULL
           AND o.blocked_at IS NULL
           AND a.deleted_at IS NULL
           AND a.blocked_at IS NULL
      ORDER BY t.id DESC
         LIMIT 1
      QUERY
      ActivityPub::Object.query_all(query, name).first?
    end

    # Returns the objects with the given hashtag.
    #
    # Includes private (not visible) objects.
    #
    # Orders objects by `id` for consistency with the query above.
    #
    def self.all_objects(name, page = 1, size = 10)
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM objects AS o
          JOIN tags AS t
            ON t.subject_iri = o.iri
           AND t.type = "#{self}"
          JOIN actors AS a
            ON a.iri = o.attributed_to_iri
         WHERE t.name = ?
           AND o.published IS NOT NULL
           AND o.deleted_at IS NULL
           AND o.blocked_at IS NULL
           AND a.deleted_at IS NULL
           AND a.blocked_at IS NULL
      ORDER BY t.id DESC
         LIMIT ? OFFSET ?
      QUERY
      ActivityPub::Object.query_and_paginate(query, name, page: page, size: size)
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

    # Returns the site's public posts with the given hashtag.
    #
    # Does not include private (not visible) posts. Includes
    # other's posts that have been shared.
    #
    def self.public_objects(name, page = 1, size = 10)
      # note: disqualify the index on tag *name* because, although it
      # has high cardinality, the distribution of names is very uneven
      # and this method is likely to be called on those tags it would
      # help the least (the most popular).
      query = <<-QUERY
        SELECT #{ActivityPub::Object.columns(prefix: "o")}
          FROM objects AS o
          JOIN activities AS a
            ON a.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
           AND a.object_iri = o.iri
          JOIN relationships AS r
            ON r.type = '#{Relationship::Content::Outbox}'
           AND r.to_iri = a.iri
          JOIN actors AS t
            ON t.iri = o.attributed_to_iri
          JOIN tags AS g
            ON g.subject_iri = o.iri
           AND g.type = '#{Tag::Hashtag}'
           AND +g.name = ?
         WHERE o.visible = 1
           AND o.published IS NOT NULL
           AND o.deleted_at IS NULL
           AND o.blocked_at IS NULL
           AND t.deleted_at IS NULL
           AND t.blocked_at IS NULL
           AND a.undone_at IS NULL
        ORDER BY r.id DESC
           LIMIT ? OFFSET ?
      QUERY
      ActivityPub::Object.query_and_paginate(query, name, page: page, size: size)
    end

    # Returns the count of public posts with the given hashtag.
    #
    # Does not include private (not visible) posts. Includes
    # other's posts that have been shared.
    #
    def self.public_objects_count(name)
      # note: disqualify the index on tag *name* because, although it
      # has high cardinality, the distribution of names is very uneven
      # and this method is likely to be called on those tags it would
      # help the least (the most popular).
      query = <<-QUERY
        SELECT count(*)
          FROM objects AS o
          JOIN activities AS a
            ON a.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
           AND a.object_iri = o.iri
          JOIN relationships AS r
            ON r.type = '#{Relationship::Content::Outbox}'
           AND r.to_iri = a.iri
          JOIN actors AS t
            ON t.iri = o.attributed_to_iri
          JOIN tags AS g
            ON g.subject_iri = o.iri
           AND g.type = '#{Tag::Hashtag}'
           AND +g.name = ?
         WHERE o.visible = 1
           AND o.published IS NOT NULL
           AND o.deleted_at IS NULL
           AND o.blocked_at IS NULL
           AND t.deleted_at IS NULL
           AND t.blocked_at IS NULL
           AND a.undone_at IS NULL
      QUERY
      ActivityPub::Object.scalar(query, name).as(Int64)
    end
  end
end
