require "json"

require "./actor"
require "./collection"
require "../activity_pub"
require "../activity_pub/mixins/blockable"
require "../relationship/content/approved"
require "../relationship/content/canonical"
require "../../framework/json_ld"
require "../../framework/model"
require "../../framework/model/**"
require "../../utils/html"

require "../../views/view_helper"

module ObjectModelRenderer
  include Ktistec::ViewHelper

  def self.to_json_ld(object, recursive)
    render "src/views/objects/object.json.ecr"
  end
end

module ActivityPub
  class Object
    include Ktistec::Model
    include Ktistec::Model::Common
    include Ktistec::Model::Linked
    include Ktistec::Model::Serialized
    include Ktistec::Model::Polymorphic
    include Ktistec::Model::Deletable
    include Ktistec::Model::Blockable
    include Ktistec::Model::Renderable
    include ActivityPub

    @@table_name = "objects"

    @[Persistent]
    property visible : Bool { false }

    @[Persistent]
    property published : Time?

    @[Persistent]
    property attributed_to_iri : String?
    belongs_to attributed_to, class_name: ActivityPub::Actor, foreign_key: attributed_to_iri, primary_key: iri

    @[Persistent]
    property in_reply_to_iri : String?
    belongs_to in_reply_to, class_name: ActivityPub::Object, foreign_key: in_reply_to_iri, primary_key: iri

    # don't use an association for `replies` because it's a collection
    # and associations are automatically saved by default.

    @[Persistent]
    property replies_iri : String?
    @[Assignable]
    property! replies : ActivityPub::Collection

    @[Persistent]
    property thread : String?

    @[Persistent]
    property to : Array(String)?

    @[Persistent]
    property cc : Array(String)?

    @[Persistent]
    property name : String?

    @[Persistent]
    property summary : String?

    @[Persistent]
    property content : String?

    @[Persistent]
    property media_type : String?

    struct Source
      include JSON::Serializable

      property content : String

      @[JSON::Field(key: "mediaType")]
      property media_type : String

      def initialize(@content, @media_type)
      end
    end

    @[Persistent]
    property source : Source?

    struct Attachment
      include JSON::Serializable

      property url : String

      @[JSON::Field(key: "mediaType")]
      property media_type : String

      @[JSON::Field(key: "name")]
      property caption : String?

      def initialize(@url, @media_type, @caption = nil)
      end

      def image?
        media_type.in?(%w[image/bmp image/gif image/jpeg image/png image/svg+xml image/x-icon image/apng image/webp])
      end

      def video?
        media_type.in?(%w[video/mp4 video/webm video/ogg])
      end

      def audio?
        media_type.in?(%w[audio/mpeg audio/mp4 audio/webm audio/ogg audio/flac])
      end
    end

    @[Persistent]
    property attachments : Array(Attachment)?

    @[Persistent]
    property urls : Array(String)?

    has_many hashtags, class_name: Tag::Hashtag, foreign_key: subject_iri, primary_key: iri, inverse_of: subject
    has_many mentions, class_name: Tag::Mention, foreign_key: subject_iri, primary_key: iri, inverse_of: subject

    def before_validate
      if changed?(:source)
        clear!(:source)
        if (source = self.source) && local?
          media_type = source.media_type.split(";").map(&.strip).first?
          if media_type == "text/html"
            # remove old mentions
            if (old_to = self.to)
              self.to = old_to - self.mentions.map(&.href).compact
            end

            enhancements = Ktistec::HTML.enhance(source.content)
            self.content = enhancements.content
            self.media_type = media_type
            self.attachments = enhancements.attachments
            self.hashtags = enhancements.hashtags
            self.mentions = enhancements.mentions

            # add new mentions
            new_to = enhancements.mentions.map(&.href).compact
            if (old_to = self.to)
              self.to = old_to | new_to
            else
              self.to = new_to
            end
          end
        end
      end
    end

    # indicates whether or not the content is best presented
    # externally--at the source--or internally via the web front end.
    # subclasses should redefine this, as appropriate.

    @@external : Bool = true

    def external?
      @@external
    end

    def root?
      @iri == @thread && @in_reply_to_iri.nil?
    end

    def draft?
      published.nil? && local?
    end

    def display_link
      urls.try(&.first?) || iri
    end

    def display_date(timezone = nil)
      date(timezone).to_s("%l:%M%p · %b %-d, %Y").lstrip(' ')
    end

    def short_date(timezone = nil)
      (date = self.date(timezone)) < 1.day.ago ? date.to_s("%b %-d, %Y").lstrip(' ') : date.to_s("%l:%M%p").lstrip(' ')
    end

    private def date(timezone)
      timezone ||= Time::Location.local
      (published || created_at).in(timezone)
    end

    # Returns federated posts.
    #
    # Includes local posts. Does not include private (not visible)
    # posts.
    #
    def self.federated_posts(page = 1, size = 10)
      query = <<-QUERY
          SELECT #{Object.columns(prefix: "o")}
            FROM objects AS o
            JOIN actors AS t
              ON t.iri = o.attributed_to_iri
           WHERE o.visible = 1
             AND o.deleted_at is NULL
             AND o.blocked_at is NULL
             AND t.deleted_at IS NULL
             AND t.blocked_at IS NULL
        ORDER BY o.id DESC
           LIMIT ? OFFSET ?
      QUERY
      Object.query_and_paginate(query, page: page, size: size)
    end

    # Returns the count of federated posts.
    #
    # Includes local posts. Does not include private (not visible)
    # posts.
    #
    def self.federated_posts_count
      query = <<-QUERY
          SELECT COUNT(o.id)
            FROM objects AS o
            JOIN actors AS t
              ON t.iri = o.attributed_to_iri
           WHERE o.visible = 1
             AND o.deleted_at is NULL
             AND o.blocked_at is NULL
             AND t.deleted_at IS NULL
             AND t.blocked_at IS NULL
      QUERY
      Object.scalar(query).as(Int64)
    end

    # Returns the site's public posts.
    #
    # Does not include private (not visible) posts and replies.
    #
    def self.public_posts(page = 1, size = 10)
      query = <<-QUERY
          SELECT #{Object.columns(prefix: "o")}
            FROM accounts AS c
            JOIN relationships AS r
              ON likelihood(r.from_iri = c.iri, 0.99)
             AND r.type = "#{Relationship::Content::Outbox}"
            JOIN activities AS a
              ON a.iri = r.to_iri
             AND a.type IN ("#{ActivityPub::Activity::Announce}", "#{ActivityPub::Activity::Create}")
            JOIN objects AS o
              ON o.iri = a.object_iri
            JOIN actors AS t
              ON t.iri = o.attributed_to_iri
           WHERE o.visible = 1
             AND likelihood(o.in_reply_to_iri IS NULL, 0.25)
             AND o.deleted_at IS NULL
             AND o.blocked_at IS NULL
             AND t.deleted_at IS NULL
             AND t.blocked_at IS NULL
             AND a.undone_at IS NULL
          ORDER BY r.id DESC
             LIMIT ? OFFSET ?
      QUERY
      Object.query_and_paginate(query, page: page, size: size)
    end

    # Returns the count of the site's public posts.
    #
    # Does not include private (not visible) posts and replies.
    #
    def self.public_posts_count
      query = <<-QUERY
          SELECT COUNT(o.id)
            FROM accounts AS c
            JOIN relationships AS r
              ON likelihood(r.from_iri = c.iri, 0.99)
             AND r.type = "#{Relationship::Content::Outbox}"
            JOIN activities AS a
              ON a.iri = r.to_iri
             AND a.type IN ("#{ActivityPub::Activity::Announce}", "#{ActivityPub::Activity::Create}")
            JOIN objects AS o
              ON o.iri = a.object_iri
            JOIN actors AS t
              ON t.iri = o.attributed_to_iri
           WHERE o.visible = 1
             AND likelihood(o.in_reply_to_iri IS NULL, 0.25)
             AND o.deleted_at IS NULL
             AND o.blocked_at IS NULL
             AND t.deleted_at IS NULL
             AND t.blocked_at IS NULL
             AND a.undone_at IS NULL
      QUERY
      Object.scalar(query).as(Int64)
    end

    @[Assignable]
    property announces_count : Int64 = 0

    @[Assignable]
    property likes_count : Int64 = 0

    def with_statistics!
      query = <<-QUERY
         SELECT sum(a.type = "ActivityPub::Activity::Announce") AS announces, sum(a.type = "ActivityPub::Activity::Like") AS likes
           FROM activities AS a
          WHERE a.undone_at IS NULL
            AND a.object_iri = ?
      QUERY
      Ktistec.database.query_one(query, iri) do |rs|
        rs.read(Int64?).try { |announces_count| self.announces_count = announces_count }
        rs.read(Int64?).try { |likes_count| self.likes_count = likes_count }
      end
      self
    end

    @[Assignable]
    property replies_count : Int64 = 0

    private def with_replies_count_query_with_recursive
      <<-QUERY
      WITH RECURSIVE
       replies_to(iri) AS (
         VALUES(?)
            UNION
           SELECT o.iri
             FROM objects AS o, replies_to AS t
             JOIN actors AS a
               ON a.iri = o.attributed_to_iri
            WHERE o.in_reply_to_iri = t.iri
              AND o.deleted_at IS NULL
              AND o.blocked_at IS NULL
              AND a.deleted_at IS NULL
              AND a.blocked_at IS NULL
        )
      QUERY
    end

    def with_replies_count!
      query = <<-QUERY
      #{with_replies_count_query_with_recursive}
      SELECT count(o.iri) - 1
        FROM objects AS o, replies_to AS r
       WHERE o.iri IN (r.iri)
      QUERY
      Object.scalar(query, iri).as(Int64?).try { |replies_count| self.replies_count = replies_count }
      self
    end

    def with_replies_count!(approved_by)
      query = <<-QUERY
      #{with_replies_count_query_with_recursive}
         SELECT count(o.iri) - 1
           FROM objects AS o, replies_to AS t
      LEFT JOIN relationships AS r
             ON r.type = "#{Relationship::Content::Approved}"
             AND r.from_iri = ? AND r.to_iri = o.iri
          WHERE o.iri IN (t.iri)
            AND ((o.in_reply_to_iri IS NULL) OR (r.id IS NOT NULL))
      QUERY
      from_iri = approved_by.responds_to?(:iri) ? approved_by.iri : approved_by.to_s
      Object.scalar(query, iri, from_iri).as(Int64?).try { |replies_count| self.replies_count = replies_count }
      self
    end

    # Returns all replies to this object.
    #
    # Intended for presenting an object's replies to an authorized
    # user (one who may see all objects).
    #
    # The `for_actor` parameter must be specified to disambiguate this
    # method from the `replies` property getter, but is not currently
    # used.
    #
    def replies(*, for_actor)
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
           JOIN actors AS a
             ON a.iri = o.attributed_to_iri
          WHERE o.in_reply_to_iri = ?
            AND o.deleted_at IS NULL
            AND o.blocked_at IS NULL
            AND a.deleted_at IS NULL
            AND a.blocked_at IS NULL
       ORDER BY o.published DESC
      QUERY
      Object.query_all(query, iri)
    end

    # Returns all replies to this object which have been approved by
    # `approved_by`.
    #
    # Intended for presenting an object's replies to an unauthorized
    # user (one who may not see all objects e.g. an anonymous user).
    #
    def replies(*, approved_by)
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
           JOIN actors AS a
             ON a.iri = o.attributed_to_iri
           JOIN relationships AS r
             ON r.type = "#{Relationship::Content::Approved}"
            AND r.from_iri = ? AND r.to_iri = o.iri
          WHERE o.in_reply_to_iri = ?
            AND o.deleted_at IS NULL
            AND o.blocked_at IS NULL
            AND a.deleted_at IS NULL
            AND a.blocked_at IS NULL
       ORDER BY o.published DESC
      QUERY
      from_iri = approved_by.responds_to?(:iri) ? approved_by.iri : approved_by.to_s
      Object.query_all(query, from_iri, iri)
    end

    @[Assignable]
    property depth : Int32 = 0

    private def thread_query_with_recursive
      query = <<-QUERY
      WITH RECURSIVE
       ancestors_of(iri, depth) AS (
           VALUES(?, 0)
            UNION
           SELECT o.in_reply_to_iri AS iri, p.depth + 1 AS depth
             FROM objects AS o, ancestors_of AS p
             JOIN actors AS a
               ON a.iri = o.attributed_to_iri
            WHERE o.iri = p.iri AND o.in_reply_to_iri IS NOT NULL
              AND o.deleted_at IS NULL
              AND o.blocked_at IS NULL
              AND a.deleted_at IS NULL
              AND a.blocked_at IS NULL
         ORDER BY depth DESC
       ),
       replies_to(iri, position, depth) AS (
         SELECT * FROM (SELECT iri, "", 0 FROM ancestors_of ORDER BY depth DESC LIMIT 1)
            UNION
           SELECT o.iri, r.position || "." || o.id, r.depth + 1 AS depth
             FROM objects AS o, replies_to AS r
             JOIN actors AS a
               ON a.iri = o.attributed_to_iri
            WHERE o.in_reply_to_iri = r.iri
              AND o.deleted_at IS NULL
              AND o.blocked_at IS NULL
              AND a.deleted_at IS NULL
              AND a.blocked_at IS NULL
         ORDER BY depth DESC
        )
      QUERY
    end

    # Returns all objects in the thread to which this object belongs.
    #
    # Intended for presenting a thread to an authorized user (one who
    # may see all objects in a thread).
    #
    # The `for_actor` parameter must be specified to disambiguate this
    # method from the `thread` property getter, but is not currently
    # used.
    #
    def thread(*, for_actor)
      query = <<-QUERY
         #{thread_query_with_recursive}
         SELECT #{Object.columns(prefix: "o")}, r.depth
           FROM objects AS o, replies_to AS r
          WHERE o.iri IN (r.iri)
          ORDER BY r.position
      QUERY
      Object.query_all(query, iri, additional_columns: {depth: Int32})
    end

    # Returns all objects in the thread to which this object belongs
    # which have been approved by `approved_by`.
    #
    # Intended for presenting a thread to an unauthorized user (one
    # who may not see all objects in a thread e.g. an anonymous
    # user).
    #
    def thread(*, approved_by)
      query = <<-QUERY
         #{thread_query_with_recursive}
         SELECT #{Object.columns(prefix: "o")}, t.depth
           FROM objects AS o, replies_to AS t
      LEFT JOIN relationships AS r
             ON r.type = "#{Relationship::Content::Approved}"
            AND r.from_iri = ? AND r.to_iri = o.iri
          WHERE o.iri IN (t.iri)
            AND ((o.in_reply_to_iri IS NULL) OR (r.id IS NOT NULL))
          ORDER BY t.position
      QUERY
      from_iri = approved_by.responds_to?(:iri) ? approved_by.iri : approved_by.to_s
      Object.query_all(query, iri, from_iri, additional_columns: {depth: Int32})
    end

    private def ancestors_with_recursive
      <<-QUERY
      WITH RECURSIVE
       ancestors_of(iri, depth) AS (
          VALUES(?, 0)
           UNION
          SELECT o.in_reply_to_iri AS iri, p.depth + 1 AS depth
            FROM objects AS o, ancestors_of AS p
            JOIN actors AS a
              ON a.iri = o.attributed_to_iri
           WHERE o.iri = p.iri AND o.in_reply_to_iri IS NOT NULL
             AND o.deleted_at IS NULL
             AND o.blocked_at IS NULL
             AND a.deleted_at IS NULL
             AND a.blocked_at IS NULL
        ORDER BY depth DESC
      )
      QUERY
    end

    def ancestors
      query = <<-QUERY
      #{ancestors_with_recursive}
      SELECT #{Object.columns(prefix: "o")}, p.depth
        FROM objects AS o, ancestors_of AS p
        JOIN actors AS a
          ON a.iri = o.attributed_to_iri
       WHERE o.iri IN (p.iri)
         AND o.deleted_at IS NULL
         AND o.blocked_at IS NULL
         AND a.deleted_at IS NULL
         AND a.blocked_at IS NULL
      QUERY
      Object.query_all(query, iri, additional_columns: {depth: Int32})
    end

    def ancestors(approved_by)
      query = <<-QUERY
      #{ancestors_with_recursive}
         SELECT #{Object.columns(prefix: "o")}, p.depth
           FROM objects AS o, ancestors_of AS p
           JOIN actors AS a
             ON a.iri = o.attributed_to_iri
      LEFT JOIN relationships AS r
             ON r.type = "#{Relationship::Content::Approved}"
            AND r.from_iri = ? AND r.to_iri = o.iri
          WHERE o.iri IN (p.iri)
            AND ((o.in_reply_to_iri IS NULL) OR (r.id IS NOT NULL))
            AND o.deleted_at IS NULL
            AND o.blocked_at IS NULL
            AND a.deleted_at IS NULL
            AND a.blocked_at IS NULL
      QUERY
      from_iri = approved_by.responds_to?(:iri) ? approved_by.iri : approved_by.to_s
      Object.query_all(query, iri, from_iri, additional_columns: {depth: Int32})
    end

    def activities(inclusion = nil, exclusion = nil)
      inclusion =
        case inclusion
        when Class, String
          %Q|AND a.type = "#{inclusion}"|
        when Array
          %Q|AND a.type IN (#{inclusion.map(&.to_s.inspect).join(",")})|
        end
      exclusion =
        case exclusion
        when Class, String
          %Q|AND a.type != "#{exclusion}"|
        when Array
          %Q|AND a.type NOT IN (#{exclusion.map(&.to_s.inspect).join(",")})|
        end
      query = <<-QUERY
         SELECT #{Activity.columns(prefix: "a")}
           FROM activities AS a
           JOIN actors AS t
             ON t.iri = a.actor_iri
          WHERE a.object_iri = ?
            #{inclusion}
            #{exclusion}
            AND t.deleted_at IS NULL
            AND t.blocked_at IS NULL
            AND a.undone_at IS NULL
       ORDER BY a.id ASC
      QUERY
      Activity.query_all(query, iri)
    end

    def approved_by?(approved_by)
      from_iri = approved_by.responds_to?(:iri) ? approved_by.iri : approved_by.to_s
      Relationship::Content::Approved.count(from_iri: from_iri, to_iri: iri) > 0
    end

    @[Assignable]
    @canonical_path : String?

    @canonical_path_changed : Bool = false

    def canonical_path
      @canonical_path ||= Relationship::Content::Canonical.find?(to_iri: path).try(&.from_iri)
    end

    def canonical_path=(@canonical_path)
      @canonical_path_changed = true
      @canonical_path
    end

    def validate_model
      if @canonical_path_changed && (canonical_path = @canonical_path)
        canonical =
          Relationship::Content::Canonical.find?(to_iri: path).try(&.assign(from_iri: canonical_path)) ||
          Relationship::Content::Canonical.new(to_iri: path, from_iri: canonical_path)
        unless canonical.valid?
          canonical.errors.each do |key, value|
            errors["canonical_path.#{key}"] = value
          end
        end
      end
    end

    def before_save
      if @canonical_path_changed
        @canonical_path_changed = false
        if (canonical = Relationship::Content::Canonical.find?(to_iri: path)) && canonical.from_iri != @canonical_path
          if (urls = self.urls)
            urls.delete("#{Ktistec.host}#{canonical.from_iri}")
          end
          canonical.destroy
        end
        if (canonical.nil? || canonical.from_iri != @canonical_path) && (canonical_path = @canonical_path)
          canonical = Relationship::Content::Canonical.new(from_iri: canonical_path, to_iri: path).save
          if (urls = self.urls)
            urls << "#{Ktistec.host}#{canonical_path}"
          else
            self.urls = ["#{Ktistec.host}#{canonical_path}"]
          end
        end
      end
      # update thread
      new_thread =
        if self.in_reply_to_iri
          if self.in_reply_to? && self.in_reply_to.thread
            self.in_reply_to.thread
          elsif self.in_reply_to? && self.in_reply_to.in_reply_to_iri
            self.in_reply_to.in_reply_to_iri
          else
            self.in_reply_to_iri
          end
        else
          self.iri
        end
      if self.thread != new_thread
        self.thread = new_thread
      end
    end

    def after_save
      # update thread in replies
      self.class.where(in_reply_to: self).each do |reply|
        if reply.thread != self.thread
          reply.save
        end
      end
      # see the source for Relationship::Content::Follow::Thread and
      # Task::Fetch::Thread for additional after_save thread updating
      # functionality
    end

    def after_delete
      Relationship::Content::Canonical.find?(to_iri: path).try(&.destroy)
      @canonical_path = nil
    end

    def after_destroy
      Relationship::Content::Canonical.find?(to_iri: path).try(&.destroy)
      @canonical_path = nil
    end

    private def path
      URI.parse(iri).path
    end

    def tags
      hashtags + mentions
    end

    def to_json_ld(recursive = true)
      ObjectModelRenderer.to_json_ld(self, recursive)
    end

    def from_json_ld(json)
      self.assign(self.class.map(json))
    end

    def self.map(json : JSON::Any | String | IO, **options)
      json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
      {
        "iri" => json.dig?("@id").try(&.as_s),
        "_type" => json.dig?("@type").try(&.as_s.split("#").last),
        "published" => (p = dig?(json, "https://www.w3.org/ns/activitystreams#published")) ? Time.parse_rfc3339(p) : nil,
        "attributed_to_iri" => dig_id?(json, "https://www.w3.org/ns/activitystreams#attributedTo"),
        "in_reply_to_iri" => dig_id?(json, "https://www.w3.org/ns/activitystreams#inReplyTo"),
        # either pick up the collection's id or the embedded collection
        "replies_iri" => json.dig?("https://www.w3.org/ns/activitystreams#replies").try(&.as_s?),
        "replies" => if (replies = json.dig?("https://www.w3.org/ns/activitystreams#replies")) && replies.as_h?
          Collection.from_json_ld(replies)
        end,
        "to" => to = dig_ids?(json, "https://www.w3.org/ns/activitystreams#to"),
        "cc" => cc = dig_ids?(json, "https://www.w3.org/ns/activitystreams#cc"),
        "name" => dig?(json, "https://www.w3.org/ns/activitystreams#name", "und"),
        "summary" => dig?(json, "https://www.w3.org/ns/activitystreams#summary", "und"),
        "content" => dig?(json, "https://www.w3.org/ns/activitystreams#content", "und"),
        "media_type" => dig?(json, "https://www.w3.org/ns/activitystreams#mediaType"),
        "hashtags" => dig_values?(json, "https://www.w3.org/ns/activitystreams#tag") do |tag|
          next unless tag.dig?("@type") == "https://www.w3.org/ns/activitystreams#Hashtag"
          name = dig?(tag, "https://www.w3.org/ns/activitystreams#name", "und").presence
          href = dig?(tag, "https://www.w3.org/ns/activitystreams#href").presence
          Tag::Hashtag.new(name: name, href: href) if name
        end,
        "mentions" => dig_values?(json, "https://www.w3.org/ns/activitystreams#tag") do |tag|
          next unless tag.dig?("@type") == "https://www.w3.org/ns/activitystreams#Mention"
          name = dig?(tag, "https://www.w3.org/ns/activitystreams#name", "und").presence
          href = dig?(tag, "https://www.w3.org/ns/activitystreams#href").presence
          Tag::Mention.new(name: name, href: href) if name
        end,
        "attachments" => dig_values?(json, "https://www.w3.org/ns/activitystreams#attachment") do |attachment|
          url = dig?(attachment, "https://www.w3.org/ns/activitystreams#url").presence
          media_type = dig?(attachment, "https://www.w3.org/ns/activitystreams#mediaType").presence
          name = dig?(attachment, "https://www.w3.org/ns/activitystreams#name", "und").presence
          Attachment.new(url, media_type, name) if url && media_type
        end,
        "urls" => dig_ids?(json, "https://www.w3.org/ns/activitystreams#url"),
        # use addressing to establish visibility
        "visible" => [to, cc].compact.flatten.includes?("https://www.w3.org/ns/activitystreams#Public")
      }.compact
    end

    def make_delete_activity
      ActivityPub::Activity::Delete.new(
        iri: "#{Ktistec.host}/activities/#{Ktistec::Util.id}",
        actor: attributed_to,
        object: self,
        to: to,
        cc: cc
      )
    end
  end
end
