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
    end

    # Returns the most recent objects with the given mention.
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
           AND t.type = "#{Tag::Mention}"
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
    def self.all_objects_count(name)
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
