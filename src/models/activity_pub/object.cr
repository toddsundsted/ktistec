require "json"
require "markd"

require "./actor"
require "./collection"
require "../activity_pub"
require "../activity_pub/mixins/blockable"
require "../relationship/content/approved"
require "../relationship/content/canonical"
require "../../services/thread_analysis_service"
require "../translation"
require "../tag/emoji"
require "../../framework/json_ld"
require "../../framework/model"
require "../../framework/model/**"
require "../../utils/html"

require "../../views/view_helper"

module ActivityPub
  class Object
    include Ktistec::Model
    include Ktistec::Model::Common
    include Ktistec::Model::Linked
    include Ktistec::Model::Polymorphic
    include Ktistec::Model::Deletable
    include Ktistec::Model::Blockable
    include ActivityPub

    @@table_name = "objects"

    # Note: a Question is an object, as per Mastodon's implementation:
    #   https://docs.joinmastodon.org/spec/activitypub/#Question
    # It is not an activity, as per the Activity Streams specification:
    #   https://www.w3.org/TR/activitystreams-vocabulary/#dfn-question

    ALIASES = [
      "ActivityPub::Object::Audio",
      "ActivityPub::Object::Event",
      "ActivityPub::Object::Image",
      "ActivityPub::Object::Page",
      "ActivityPub::Object::Place",
      "ActivityPub::Object::Video",
    ]

    @[Persistent]
    property visible : Bool { false }

    @[Persistent]
    property sensitive : Bool { false }

    @[Persistent]
    property special : String?

    @[Persistent]
    property published : Time?

    @[Persistent]
    property updated : Time?

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
    property audience : Array(String)?

    @[Persistent]
    property name : String? # plain text

    @[Persistent]
    property summary : String?  # depends on media_type / default HTML text

    @[Persistent]
    property content : String?  # depends on media_type / default HTML text

    @[Persistent]
    property media_type : String?

    @[Persistent]
    property language : String?
    validates(language) do
      if language
        "is unsupported" unless language =~ Ktistec::Constants::LANGUAGE_RE
      end
    end

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

      @[JSON::Field(key: "focalPoint")]
      property focal_point : Tuple(Float64, Float64)?

      def initialize(@url, @media_type, @caption = nil, @focal_point = nil)
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

      def has_focal_point?
        return false unless (fp = focal_point)
        fp[0].finite? && fp[1].finite?
      end

      def normalized_focal_point
        return nil unless has_focal_point?
        x, y = focal_point.not_nil!
        norm_x = x / 2 + 0.5      # normalized x = x / 2 + 0.5
        norm_y = -y / 2 + 0.5     # normalized y = -y / 2 + 0.5 (y inverted)
        # push the focal point toward the edges so that more of the focused thing is in view
        {
          exaggerate(norm_x),
          exaggerate(norm_y)
        }
      end

      private def exaggerate(value, strength = 0.75)
        # recenter value at 0
        centered = value - 0.5
        exaggerated = centered.sign * (centered.abs ** strength)
        (exaggerated + 0.5).clamp(0.0, 1.0)
      end

      def css_object_position
        return "50% 50%" unless (normalized = normalized_focal_point)
        "#{(normalized[0] * 100).round(2)}% #{(normalized[1] * 100).round(2)}%"
      end
    end

    @[Persistent]
    property attachments : Array(Attachment)?

    @[Persistent]
    property urls : Array(String)?

    has_many translations, foreign_key: origin_id, primary_key: id, inverse_of: origin

    has_many hashtags, class_name: Tag::Hashtag, foreign_key: subject_iri, primary_key: iri, inverse_of: subject
    has_many mentions, class_name: Tag::Mention, foreign_key: subject_iri, primary_key: iri, inverse_of: subject
    has_many emojis, class_name: Tag::Emoji, foreign_key: subject_iri, primary_key: iri, inverse_of: subject

    # Updates the thread and saves the object.
    #
    # On older databases, threads are lazily migrated. This is a
    # convenience method for triggering the update and save, and
    # returning the value.
    #
    def thread!
      save.thread.not_nil!
    end

    def before_validate
      if changed?(:source)
        clear_changed!(:source)
        if (source = self.source) && local?
          source_content = source.content
          media_type = source.media_type.split(";").map(&.strip).first?
          if media_type == "text/markdown"
            source_content = Markd.to_html(source_content)
            media_type = "text/html"
          end
          if media_type == "text/html"
            # remove old mentions from both to and cc
            old_mentions = self.mentions.compact_map(&.href)
            if (old_to = self.to)
              self.to = old_to - old_mentions
            end
            if (old_cc = self.cc)
              self.cc = old_cc - old_mentions
            end

            enhancements = Ktistec::HTML.enhance(source_content)
            self.content = enhancements.content
            self.media_type = media_type
            self.attachments = enhancements.attachments
            self.hashtags = enhancements.hashtags
            self.mentions = enhancements.mentions

            # add new mentions based on addressing
            new_mentions = enhancements.mentions.compact_map(&.href)
            if !new_mentions.empty?
              is_public = (to = self.to) && to.includes?("https://www.w3.org/ns/activitystreams#Public")
              is_private = to && to.includes?(attributed_to.try(&.followers))
              if is_public || is_private
                if (old_cc = self.cc)
                  self.cc = old_cc | new_mentions
                else
                  self.cc = new_mentions
                end
              else
                if (old_to = self.to)
                  self.to = old_to | new_mentions
                else
                  self.to = new_mentions
                end
              end
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

    def reply?
      !in_reply_to_iri.nil?
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

    # Returns the text to use for the preview of the object with fallback.
    #
    # The method checks for text in the following order:
    # 1. Summary from translation
    # 2. Summary from the object
    # 3. Content from translation
    # 4. Content from the object
    #
    # Returns the first non-blank value found, or `nil`.
    #
    def preview
      translation = Translation.where("origin_id = ? ORDER BY id DESC LIMIT 1", id).first?
      if translation && (name = translation.name.presence)
        ::HTML.escape name
      elsif (name = self.name.presence)
        ::HTML.escape name
      elsif translation && (summary = translation.summary.presence)
        summary
      elsif (summary = self.summary.presence)
        summary
      elsif translation && (content = translation.content.presence)
        content
      elsif (content = self.content.presence)
        content
      end
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
             #{common_filters(objects: "o", actors: "t")}
             AND NOT (o.iri LIKE '#{Ktistec.host}%' AND o.published IS NULL)
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
             #{common_filters(objects: "o", actors: "t")}
             AND NOT (o.iri LIKE '#{Ktistec.host}%' AND o.published IS NULL)
      QUERY
      Object.scalar(query).as(Int64)
    end

    # Returns the site's public posts.
    #
    # Does not include private (not visible) posts and replies.
    #
    def self.public_posts(page = 1, size = 10)
      query = <<-QUERY
          SELECT DISTINCT #{Object.columns(prefix: "o")}
            FROM accounts AS c
            JOIN relationships AS r
              ON likelihood(r.from_iri = c.iri, 0.99)
             AND r.type = '#{Relationship::Content::Outbox}'
            JOIN activities AS a
              ON a.iri = r.to_iri
             AND a.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
            JOIN objects AS o
              ON o.iri = a.object_iri
            JOIN actors AS t
              ON t.iri = o.attributed_to_iri
           WHERE o.visible = 1
             AND likelihood(o.in_reply_to_iri IS NULL, 0.25)
             #{common_filters(objects: "o", actors: "t", activities: "a")}
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
          SELECT COUNT(DISTINCT o.id)
            FROM accounts AS c
            JOIN relationships AS r
              ON likelihood(r.from_iri = c.iri, 0.99)
             AND r.type = '#{Relationship::Content::Outbox}'
            JOIN activities AS a
              ON a.iri = r.to_iri
             AND a.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
            JOIN objects AS o
              ON o.iri = a.object_iri
            JOIN actors AS t
              ON t.iri = o.attributed_to_iri
           WHERE o.visible = 1
             AND likelihood(o.in_reply_to_iri IS NULL, 0.25)
             #{common_filters(objects: "o", actors: "t", activities: "a")}
      QUERY
      Object.scalar(query).as(Int64)
    end

    # Returns an identifier associated with the latest public post.
    #
    # Skips many joins and filters in the interest of speed.
    #
    # It is intended for use in expiring cached results from the two
    # methods above. If the identifier changes, the cached results are
    # probably stale.
    #
    # NB: The "identifier" is not necessarily the `id` of the latest
    # post!
    #
    def self.latest_public_post
      query = <<-QUERY
          SELECT a.id
            FROM activities AS a
            JOIN accounts AS c
              ON c.iri = a.actor_iri
           WHERE a.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
             #{common_filters(activities: "a")}
        ORDER BY a.id DESC
           LIMIT 1
      QUERY
      Object.scalar(query).as(Int64)
    rescue DB::NoResultsError
      -1_i64
    end

    @[Assignable]
    property announces_count : Int64 = 0

    @[Assignable]
    property likes_count : Int64 = 0

    @[Assignable]
    property dislikes_count : Int64 = 0

    def with_statistics!
      query = <<-QUERY
         SELECT sum(a.type = 'ActivityPub::Activity::Announce') AS announces, sum(a.type = 'ActivityPub::Activity::Like') AS likes, sum(a.type = 'ActivityPub::Activity::Dislike') AS dislikes
           FROM activities AS a
          WHERE a.undone_at IS NULL
            AND a.object_iri = ?
      QUERY
      Internal.log_query(query) do
        Ktistec.database.query_one(query, iri) do |rs|
          rs.read(Int64?).try { |announces_count| self.announces_count = announces_count }
          rs.read(Int64?).try { |likes_count| self.likes_count = likes_count }
          rs.read(Int64?).try { |dislikes_count| self.dislikes_count = dislikes_count }
        end
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
              #{common_filters(objects: "o", actors: "a")}
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
             ON r.type = '#{Relationship::Content::Approved}'
             AND r.from_iri = ? AND r.to_iri = o.iri
          WHERE o.iri IN (t.iri)
            AND o.visible = 1
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
            #{common_filters(objects: "o", actors: "a")}
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
             ON r.type = '#{Relationship::Content::Approved}'
            AND r.from_iri = ? AND r.to_iri = o.iri
          WHERE o.in_reply_to_iri = ?
            AND o.visible = 1
            #{common_filters(objects: "o", actors: "a")}
       ORDER BY o.published DESC
      QUERY
      from_iri = approved_by.responds_to?(:iri) ? approved_by.iri : approved_by.to_s
      Object.query_all(query, from_iri, iri)
    end

    @[Assignable]
    property depth : Int32 = 0

    # This method sorts the objects in a thread by generating a
    # special position value for each object, which acts as a
    # lexicographically sortable, hierarchical key.
    #
    # 1. It uses a recursive SQL query to walk through the thread,
    #    starting from the root post.
    #
    # 2. For each object, it constructs a position string that looks
    #    like a path (e.g., .00...123.00...456). Each number is the
    #    zero-padded `id` of an object in the thread. When sorted
    #    lexicographically, this string naturally orders the thread by
    #    reply depth and creation order.
    #
    # 3. It prioritizes self-replies (replies from authors to
    #    themselves). When a reply's author is the same as its
    #    parent's author, the query negates the reply's `id` before
    #    adding it to the position string (e.g., .-00...789).
    #
    # In a lexicographical sort, a string containing a minus sign (-)
    # comes before a string with a digit in the same position. This
    # forces all of the author's own replies to be sorted immediately
    # after their parent post and before any other replies at the same
    # level.
    #
    # Note: In SQLite v3.38.0, the `printf` function was renamed to
    # `format`. The original `printf` name was retained for backwards
    # compatibility.
    #
    private def thread_query_with_recursive
      <<-QUERY
      WITH RECURSIVE
       ancestors_of(iri, depth) AS (
           VALUES(?, 0)
            UNION
           SELECT o.in_reply_to_iri AS iri, p.depth + 1 AS depth
             FROM objects AS o, ancestors_of AS p
             JOIN actors AS a
               ON a.iri = o.attributed_to_iri
            WHERE o.iri = p.iri
              AND o.in_reply_to_iri IS NOT NULL
       ),
       replies_to(iri, position, depth) AS (
           SELECT * FROM (SELECT iri, '', 0 FROM ancestors_of ORDER BY depth DESC LIMIT 1)
            UNION
           SELECT o.iri, printf('%s.%020d', r.position, CASE WHEN p.iri IS NOT NULL AND o.attributed_to_iri = p.attributed_to_iri THEN -o.id ELSE o.id END), r.depth + 1 AS depth
             FROM objects AS o, replies_to AS r
        LEFT JOIN objects AS p
               ON p.iri = r.iri
             JOIN actors AS a
               ON a.iri = o.attributed_to_iri
            WHERE o.in_reply_to_iri = r.iri
        )
      QUERY
    end

    # Returns all objects in the thread to which this object belongs.
    #
    # Intended for presenting a thread to an authorized user (one who
    # may see all objects in a thread).
    #
    # Filters out special objects (e.g. votes).
    #
    # Does not filter out deleted or blocked objects. Leaves decisions
    # about presentation of these objects and their replies to the
    # caller.
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
            AND o.special IS NULL
          ORDER BY r.position
      QUERY
      Object.query_all(query, iri, additional_columns: {depth: Int32})
    end

    # Returns all objects in the thread to which this object belongs
    # which have been approved by `approved_by`.
    #
    # Filters out special objects (e.g. votes).
    #
    # Does not filter out deleted or blocked objects. Leaves decisions
    # about presentation of these objects and their replies to the
    # caller.
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
             ON r.type = '#{Relationship::Content::Approved}'
            AND r.from_iri = ? AND r.to_iri = o.iri
          WHERE o.iri IN (t.iri)
            AND o.visible = 1
            AND o.special IS NULL
            AND ((o.in_reply_to_iri IS NULL) OR (r.id IS NOT NULL))
          ORDER BY t.position
      QUERY
      from_iri = approved_by.responds_to?(:iri) ? approved_by.iri : approved_by.to_s
      Object.query_all(query, iri, from_iri, additional_columns: {depth: Int32})
    end

    # Predefined thread query projection definitions.
    #
    PROJECTION_MINIMAL = {
      id: Int64,
      iri: String,
      in_reply_to_iri: String?,
      thread: String?,
      depth: Int32,
    }

    PROJECTION_METADATA = {
      id: Int64,
      iri: String,
      attributed_to_iri: String?,
      in_reply_to_iri: String?,
      thread: String?,
      published: Time?,
      deleted: Bool,
      blocked: Bool,
      hashtags: String?,
      mentions: String?,
      depth: Int32,
    }

    # Returns projected fields for all objects in the thread.
    #
    # The `projection` parameter accepts a `NamedTuple` that defines
    # which fields to return. Predefined constants handle common
    # use-cases:
    #
    # - PROJECTION_MINIMAL
    # - PROJECTION_METADATA
    #
    # Or specify a custom projection:
    #     projection: {id: Int64, iri: String, depth: Int32}
    #
    # Returns `Array(NamedTuple)` with named fields.
    #
    def thread_query(*, projection : T) forall T
      {% begin %}
        {% select_parts = [] of String %}
        {% needs_hashtag_join = false %}
        {% needs_mention_join = false %}
        {% needs_group_by = false %}

        {% for key in T.keys %}
          {% if key == :depth %}
            {% select_parts << "r.depth" %}
          {% elsif key == :deleted %}
            {% select_parts << "o.deleted_at IS NOT NULL AS deleted" %}
          {% elsif key == :blocked %}
            {% select_parts << "o.blocked_at IS NOT NULL AS blocked" %}
          {% elsif key == :hashtags %}
            {% select_parts << "GROUP_CONCAT(DISTINCT ht.name) AS hashtags" %}
            {% needs_hashtag_join = true %}
            {% needs_group_by = true %}
          {% elsif key == :mentions %}
            {% select_parts << "GROUP_CONCAT(DISTINCT mt.name) AS mentions" %}
            {% needs_mention_join = true %}
            {% needs_group_by = true %}
          {% else %}
            {% select_parts << "o.#{key.id}" %}
          {% end %}
        {% end %}

        query = <<-QUERY
        #{thread_query_with_recursive}
        SELECT {{select_parts.join(", ").id}}
          FROM objects AS o, replies_to AS r
          {% if needs_hashtag_join %}
          LEFT JOIN tags AS ht ON ht.subject_iri = o.iri AND ht.type = 'Tag::Hashtag'
          {% end %}
          {% if needs_mention_join %}
          LEFT JOIN tags AS mt ON mt.subject_iri = o.iri AND mt.type = 'Tag::Mention'
          {% end %}
         WHERE o.iri IN (r.iri)
           AND o.special IS NULL
         {% if needs_group_by %}
         GROUP BY o.id, r.depth, r.position
         {% end %}
         ORDER BY r.position
        QUERY
        Ktistec.database.query_all(query, iri, as: projection)
      {% end %}
    end

    # Analyzes thread structure and participation patterns.
    #
    # Returns comprehensive analysis including statistics, key
    # participants, notable branches, and timeline histogram.
    #
    def analyze_thread(*, for_actor : ActivityPub::Actor) : ThreadAnalysisService::ThreadAnalysis
      tuples = nil
      object_count = 0
      author_count = 0
      root = nil
      max_depth = 0
      histogram = nil
      participants = nil
      branches = nil

      duration = Benchmark.realtime do
        tuples = thread_query(projection: PROJECTION_METADATA)
        object_count = tuples.size
        author_count = tuples.compact_map { |t| t[:attributed_to_iri] }.uniq!.size
        root = tuples.find! { |t| t[:in_reply_to_iri].nil? }
        max_depth = tuples.max_of? { |t| t[:depth] } || 0
        histogram = ThreadAnalysisService.timeline_histogram(tuples)
        participants = ThreadAnalysisService.key_participants(tuples)
        branches = ThreadAnalysisService.notable_branches(tuples)
      end

      ThreadAnalysisService::ThreadAnalysis.new(
        thread_id: thread.not_nil!,
        root_object_id: root.not_nil![:id],
        object_count: object_count,
        author_count: author_count,
        max_depth: max_depth,
        timeline_histogram: histogram,
        key_participants: participants.not_nil!,
        notable_branches: branches.not_nil!,
        duration_ms: duration.total_milliseconds
      )
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
             #{common_filters(objects: "o", actors: "a")}
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
         #{common_filters(objects: "o", actors: "a")}
       ORDER BY p.depth
      QUERY
      Object.query_all(query, iri, additional_columns: {depth: Int32})
    end

    private def descendants_with_recursive
      <<-QUERY
      WITH RECURSIVE
       replies_to(iri, position, depth) AS (
          VALUES(?, '', 0)
           UNION
          SELECT o.iri, printf('%s.%020d', r.position, CASE WHEN p.iri IS NOT NULL AND o.attributed_to_iri = p.attributed_to_iri THEN -o.id ELSE o.id END), r.depth + 1 AS depth
            FROM objects AS o, replies_to AS r
       LEFT JOIN objects AS p
              ON p.iri = r.iri
            JOIN actors AS a
              ON a.iri = o.attributed_to_iri
           WHERE o.in_reply_to_iri = r.iri
             #{common_filters(objects: "o", actors: "a")}
      )
      QUERY
    end

    def descendants
      query = <<-QUERY
      #{descendants_with_recursive}
      SELECT #{Object.columns(prefix: "o")}, r.depth
        FROM objects AS o, replies_to AS r
       WHERE o.iri IN (r.iri)
       ORDER BY r.position
      QUERY
      Object.query_all(query, iri, additional_columns: {depth: Int32})
    end

    def activities(inclusion = nil, exclusion = nil)
      inclusion =
        case inclusion
        when Class, String
          %Q|AND a.type = '#{inclusion}'|
        when Array
          %Q|AND a.type IN ('#{inclusion.map(&.to_s).join("','")}')|
        end
      exclusion =
        case exclusion
        when Class, String
          %Q|AND a.type != '#{exclusion}'|
        when Array
          %Q|AND a.type NOT IN ('#{exclusion.map(&.to_s).join("','")}')|
        end
      query = <<-QUERY
         SELECT #{Activity.columns(prefix: "a")}
           FROM activities AS a
           JOIN actors AS t
             ON t.iri = a.actor_iri
          WHERE a.object_iri = ?
            #{common_filters(actors: "t", activities: "a")}
            #{inclusion}
            #{exclusion}
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

    private def update_canonical_path
      if @canonical_path_changed
        @canonical_path_changed = false
        if (canonical = Relationship::Content::Canonical.find?(to_iri: path)) && canonical.from_iri != @canonical_path
          if (urls = self.urls)
            urls.delete("#{Ktistec.host}#{canonical.from_iri}")
          end
          canonical.destroy
        end
        if (canonical.nil? || canonical.from_iri != @canonical_path) && (canonical_path = @canonical_path)
          Relationship::Content::Canonical.new(from_iri: canonical_path, to_iri: path).save
          if (urls = self.urls)
            urls << "#{Ktistec.host}#{canonical_path}"
          else
            self.urls = ["#{Ktistec.host}#{canonical_path}"]
          end
        end
      end
    end

    private def update_thread
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

    def before_save
      update_canonical_path
      update_thread
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

    def make_delete_activity
      ActivityPub::Activity::Delete.new(
        iri: "#{Ktistec.host}/activities/#{Ktistec::Util.id}",
        actor: attributed_to,
        object: self,
        to: to,
        cc: cc
      )
    end

    def to_json_ld(recursive = true)
      ModelHelper.to_json_ld(self, recursive)
    end

    def from_json_ld(json)
      self.assign(ModelHelper.from_json_ld(json))
    end

    def self.map(json, **options)
      ModelHelper.from_json_ld(json)
    end
  end
end

# the "object.json.ecr" view template requires the `Poll` model
require "../poll"

module ActivityPub
  class Object
    module ModelHelper
      include Ktistec::ViewHelper

      def self.to_json_ld(object, recursive)
        render "src/views/objects/object.json.ecr"
      end

      def self.from_json_ld(json : JSON::Any | String | IO)
        json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
        object_host = (object_iri = json.dig?("@id").try(&.as_s?)) ? parse_host(object_iri) : nil
        {
          "iri" => json.dig?("@id").try(&.as_s),
          "_type" => json.dig?("@type").try(&.as_s.split("#").last),
          "published" => (p = Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#published")) ? Time.parse_rfc3339(p) : nil,
          "updated" => (u = Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#updated")) ? Time.parse_rfc3339(u) : nil,
          "attributed_to_iri" => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#attributedTo"),
          "in_reply_to_iri" => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#inReplyTo"),
          # pick up the replies' id and the embedded replies if the hosts match
          "replies_iri" => if (replies = json.dig?("https://www.w3.org/ns/activitystreams#replies"))
            replies.as_s? || replies.dig?("@id").try(&.as_s?)
          end,
          "replies" => if replies && replies.as_h?
            if (replies_iri = replies.dig?("@id").try(&.as_s?))
              if parse_host(replies_iri) == object_host
                ActivityPub::Collection.from_json_ld(replies)
              end
            else
              ActivityPub::Collection.from_json_ld(replies)
            end
          end,
          "to" => to = Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#to"),
          "cc" => cc = Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#cc"),
          "audience" => Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#audience"),
          "name" => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#name", "und"),
          "summary" => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#summary", "und"),
          "sensitive" => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#sensitive", as: Bool),
          "content" => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#content", "und"),
          "media_type" => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#mediaType"),
          "hashtags" => Ktistec::JSON_LD.dig_values?(json, "https://www.w3.org/ns/activitystreams#tag") do |tag|
            next unless tag.dig?("@type") == "https://www.w3.org/ns/activitystreams#Hashtag"
            name = Ktistec::JSON_LD.dig?(tag, "https://www.w3.org/ns/activitystreams#name", "und").presence
            href = Ktistec::JSON_LD.dig?(tag, "https://www.w3.org/ns/activitystreams#href").presence
            Tag::Hashtag.new(name: name, href: href) if name
          end,
          "mentions" => Ktistec::JSON_LD.dig_values?(json, "https://www.w3.org/ns/activitystreams#tag") do |tag|
            next unless tag.dig?("@type") == "https://www.w3.org/ns/activitystreams#Mention"
            name = Ktistec::JSON_LD.dig?(tag, "https://www.w3.org/ns/activitystreams#name", "und").presence
            href = Ktistec::JSON_LD.dig?(tag, "https://www.w3.org/ns/activitystreams#href").presence
            Tag::Mention.new(name: name, href: href) if name
          end,
          "emojis" => Ktistec::JSON_LD.dig_values?(json, "https://www.w3.org/ns/activitystreams#tag") do |tag|
            next unless tag.dig?("@type") == "http://joinmastodon.org/ns#Emoji"
            name = Ktistec::JSON_LD.dig?(tag, "https://www.w3.org/ns/activitystreams#name", "und").presence
            icon_url = tag.dig?("https://www.w3.org/ns/activitystreams#icon", "https://www.w3.org/ns/activitystreams#url").try(&.as_s?)
            Tag::Emoji.new(name: name, href: icon_url) if name && icon_url
          end,
          "attachments" => Ktistec::JSON_LD.dig_values?(json, "https://www.w3.org/ns/activitystreams#attachment") do |attachment|
            url = Ktistec::JSON_LD.dig?(attachment, "https://www.w3.org/ns/activitystreams#url").presence
            media_type = Ktistec::JSON_LD.dig?(attachment, "https://www.w3.org/ns/activitystreams#mediaType").presence
            name = Ktistec::JSON_LD.dig?(attachment, "https://www.w3.org/ns/activitystreams#name", "und").presence
            focal_point =
              if (fp = attachment.as_h["http://joinmastodon.org/ns#focalPoint"]?)
                # parse as array and convert to tuple
                if (fp_array = fp.as_a?)
                  if fp_array.size == 2
                    # handle both integer [0, 0] and float [0.0, 0.0] formats
                    x = fp_array[0].as_i64?.try(&.to_f64) || fp_array[0].as_f?.try(&.to_f64)
                    y = fp_array[1].as_i64?.try(&.to_f64) || fp_array[1].as_f?.try(&.to_f64)
                    {x, y} if x && y && x.finite? && y.finite?
                  end
                end
              end
            ActivityPub::Object::Attachment.new(url, media_type, name, focal_point) if url && media_type
          end,
          "urls" => Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#url"),
          # use addressing to establish visibility
          "visible" => [to, cc].compact.flatten.includes?("https://www.w3.org/ns/activitystreams#Public")
        }.tap do |map|
          if (language = json.dig?("http://schema.org/inLanguage", "http://schema.org/identifier")) && (language = language.as_s?)
            map["language"] = language
          elsif (content = json.dig?("https://www.w3.org/ns/activitystreams#content")) && (content = content.as_h?)
            content.each do |lang, ctnt|
              if lang && ctnt
                if lang != "und" && lang =~ Ktistec::Constants::LANGUAGE_RE && ctnt == map["content"]?
                  map["language"] = lang
                  break
                end
              end
            end
          end
        end.compact
      end

      private def self.parse_host(uri)
        URI.parse(uri).host
      rescue URI::Error
      end
    end
  end
end
