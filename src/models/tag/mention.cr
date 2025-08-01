require "../tag"
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
           AND o.deleted_at IS NULL
           AND o.blocked_at IS NULL
           AND a.deleted_at IS NULL
           AND a.blocked_at IS NULL
      ORDER BY t.id DESC
         LIMIT 1
      QUERY
      ActivityPub::Object.query_all(query, name).first?
    end

    # Returns the objects with the given mention.
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
           AND t.type = '#{self}'
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
  end
end
