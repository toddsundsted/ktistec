require "json"
require "openssl_ext"

require "../../framework/util"
require "../../framework/json_ld"
require "../../framework/key_pair"
require "../../framework/ext/sqlite3"
require "../../framework/model"
require "../../framework/model/common"
require "../../services/upload_service"
require "../activity_pub"
require "../activity_pub/mixins/blockable"
require "../relationship/content/approved"
require "../relationship/content/bookmark"
require "../relationship/content/pin"
require "../relationship/content/follow/hashtag"
require "../relationship/content/follow/mention"
require "../relationship/content/notification/*" # ameba:disable Ktistec/NoRequireGlob
require "../relationship/content/timeline/*"     # ameba:disable Ktistec/NoRequireGlob
require "../relationship/content/inbox"
require "../relationship/content/outbox"
require "../relationship/social/follow"
require "../filter_term"
require "../tag/emoji"
require "./activity"
require "./activity/announce"
require "./activity/create"
require "./activity/delete"
require "./activity/dislike"
require "./activity/like"
require "./activity/undo"
require "./object"

require "../../views/view_helper"

module ActivityPub
  class Actor
    include Ktistec::Model
    include Ktistec::Model::Common
    include Ktistec::Model::Linked
    include Ktistec::Model::Polymorphic
    include Ktistec::Model::Deletable
    include Ktistec::Model::Blockable
    include Ktistec::KeyPair
    include ActivityPub

    Log = ::Log.for(self)

    ATTACHMENT_LIMIT = 6

    @@table_name = "actors"

    ALIASES = [
      "ActivityPub::Actor::Application",
      "ActivityPub::Actor::Group",
      "ActivityPub::Actor::Organization",
      "ActivityPub::Actor::Service",
    ]

    @[Persistent]
    property username : String?

    @[Persistent]
    @[Insignificant]
    property pem_public_key : String?

    @[Persistent]
    @[Insignificant]
    property pem_private_key : String?

    def public_key
      if (key = pem_public_key)
        OpenSSL::RSA.new(key, nil, false)
      end
    end

    def private_key
      if (key = pem_private_key)
        OpenSSL::RSA.new(key, nil, true)
      end
    end

    @[Persistent]
    property shared_inbox : String?

    @[Persistent]
    property inbox : String?

    @[Persistent]
    property outbox : String?

    @[Persistent]
    property following : String?

    @[Persistent]
    property followers : String?

    @[Persistent]
    property featured : String?

    @[Persistent]
    property name : String?

    @[Persistent]
    property summary : String?

    @[Persistent]
    property icon : String?

    @[Persistent]
    property image : String?

    @[Persistent]
    property urls : Array(String)?

    has_many objects, class_name: ActivityPub::Object, foreign_key: attributed_to_iri, primary_key: iri

    has_many emojis, class_name: Tag::Emoji, foreign_key: subject_iri, primary_key: iri, inverse_of: subject

    has_many filter_terms, inverse_of: actor

    # the implementation of attachments follows Mastodon's design

    struct Attachment
      include JSON::Serializable

      property name : String

      property type : String

      property value : String

      def initialize(@name, @type, @value)
      end

      # Renders the attachment value as HTML that is safe to
      # interpolate unescaped.
      #
      def value_as_html(length : Int32 = 50) : Ktistec::SafeHTML
        Ktistec::Util.wrap_link(value, length: length) || Ktistec::Util.sanitize(value)
      end
    end

    @[Persistent]
    property attachments : Array(Attachment)?

    @[Persistent]
    @[Insignificant]
    property down_at : Time?

    def before_validate
      if changed?(:username)
        clear_changed!(:username)
        if (username = self.username) && ((iri.blank? && new_record?) || local?)
          host = Ktistec.host
          self.iri = "#{host}/actors/#{username}"
          self.inbox = "#{host}/actors/#{username}/inbox"
          self.outbox = "#{host}/actors/#{username}/outbox"
          self.following = "#{host}/actors/#{username}/following"
          self.followers = "#{host}/actors/#{username}/followers"
          self.featured = "#{host}/actors/#{username}/featured"
          self.urls = ["#{host}/@#{username}"]
        end
      end
      # `icon`, `image`, and entries in `urls` arrive from federated
      # actor documents and flow into Slang `href=`/`src=` attributes
      # in templates. drop entries whose scheme is not on the
      # `safe_url?` allowlist. log with the scheme so the operator can
      # spot legitimate-but-unrecognized schemes arriving from new
      # Fediverse software (the allowlist will need an addition).
      # `attachments` is intentionally NOT scrubbed: per Mastodon's
      # `PropertyValue` convention the `value` field is freeform
      # text/HTML/URL, not contractually a URL, and applying
      # `safe_url?` to it would drop legitimate content.
      if (icon = @icon) && !Ktistec::Util.safe_url?(icon)
        Log.warn { "actor.icon scheme=#{Ktistec::Util.url_scheme(icon).inspect} iri=#{iri.inspect}" }
        self.icon = nil
      end
      if (image = @image) && !Ktistec::Util.safe_url?(image)
        Log.warn { "actor.image scheme=#{Ktistec::Util.url_scheme(image).inspect} iri=#{iri.inspect}" }
        self.image = nil
      end
      if (urls = @urls)
        safe = urls.select { |u| Ktistec::Util.safe_url?(u) }
        if safe.size != urls.size
          (urls - safe).each do |dropped|
            Log.warn { "actor.urls scheme=#{Ktistec::Util.url_scheme(dropped).inspect} iri=#{iri.inspect}" }
          end
          self.urls = safe
        end
      end
      # custom emoji `href` (the icon URL) arrives raw from federated
      # JSON-LD with no scheme check upstream. drop the entire emoji
      # tag if href is unsafe -- `Tag::Emoji.validates(href)` requires
      # presence, and `Ktistec::Emoji.emojify` calls `href.not_nil!`.
      if (emojis = @emojis)
        filtered = emojis.reject do |e|
          if (href = e.href) && !Ktistec::Util.safe_url?(href)
            Log.warn { "actor.emojis dropped scheme=#{Ktistec::Util.url_scheme(href).inspect} iri=#{iri.inspect}" }
            true
          else
            false
          end
        end
        if filtered.size != emojis.size
          self.emojis = filtered
        end
      end
    end

    def before_save
      if local? && (saved = @saved_record) && (actor_id = self.id)
        if changed?(:icon) && (old_icon = saved.icon) && old_icon != icon
          if (path = URI.parse(old_icon).path)
            UploadService.delete(path, actor_id)
          end
        end
        if changed?(:image) && (old_image = saved.image) && old_image != image
          if (path = URI.parse(old_image).path)
            UploadService.delete(path, actor_id)
          end
        end
      end
    end

    def handle
      blocked? ? "[blocked]" : %Q|#{username}@#{URI.parse(iri).host}|
    end

    def display_name
      blocked? ? "[blocked]" : (name.presence || username.presence || iri)
    end

    def display_link : Ktistec::SafeURI?
      Ktistec::SafeURI.from?(urls.try(&.first?) || iri)
    end

    def icon_safe : Ktistec::SafeURI?
      icon.try { |i| Ktistec::SafeURI.from?(i) }
    end

    def image_safe : Ktistec::SafeURI?
      image.try { |i| Ktistec::SafeURI.from?(i) }
    end

    def self.match?(account)
      if account =~ /^@?([^@]+)@([^@]+)$/
        where(username: $1).find do |actor|
          urls = (actor.urls || [] of String) | [actor.iri]
          urls.any? do |url|
            uri = URI.parse(url)
            uri.host.try(&.downcase) == $2.downcase && uri.path.split(%r|[@/]|).last.downcase == $1.downcase
          rescue URI::Error
          end
        end
      end
    end

    # Searches for actors whose username starts with the given prefix.
    #
    # Returns actors in alphabetical order by username. Filters out
    # deleted and blocked actors. Treats SQL LIKE wildcards (% and _)
    # as literal characters.
    #
    def self.search_by_username(prefix, limit = 10)
      query = <<-QUERY
        SELECT #{columns}
          FROM actors
         WHERE username LIKE ? ESCAPE '\\'
           AND deleted_at IS NULL
           AND blocked_at IS NULL
      ORDER BY username ASC
         LIMIT ?
      QUERY
      escaped_prefix = prefix.gsub("%", "\\%").gsub("_", "\\_")
      query_all(query, "#{escaped_prefix}%", limit)
    end

    def down?
      !!down_at
    end

    def down!
      @down_at = Time.local
      update_property(:down_at, @down_at) unless new_record?
      self
    end

    def up?
      !down_at
    end

    def up!
      @down_at = nil
      update_property(:down_at, @down_at) unless new_record?
      self
    end

    def follow(other : Actor, **options)
      Relationship::Social::Follow.new(**options.merge({actor: self, object: other}))
    end

    def follows?(other : Actor, **options)
      !other.deleted? && !other.blocked? ? Relationship::Social::Follow.find?(**options.merge({actor: self, object: other})) : nil
    end

    private def social_cursor_query(type, orig, dest, public = true)
      public = public ? "AND r.confirmed = 1 AND r.visible = 1" : nil
      <<-QUERY
        SELECT #{Actor.columns(prefix: "a")}
          FROM actors AS a, relationships AS r
         WHERE a.iri = r.#{orig}
           #{common_filters(actors: "a")}
           AND r.type = '#{type}'
           AND r.#{dest} = ?
           #{public}
           AND %{cursor_condition}
      QUERY
    end

    def all_following(*, max_id = nil, min_id = nil, limit = 10, public = true)
      Actor.query_with_cursor(
        social_cursor_query(Relationship::Social::Follow, :to_iri, :from_iri, public),
        self.iri, cursor_column: "a.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    def all_followers(*, max_id = nil, min_id = nil, limit = 10, public = false)
      Actor.query_with_cursor(
        social_cursor_query(Relationship::Social::Follow, :from_iri, :to_iri, public),
        self.iri, cursor_column: "a.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    def all_follow_requests(*, max_id = nil, min_id = nil, limit = 10)
      query = <<-QUERY
        SELECT #{Actor.columns(prefix: "a")}
          FROM actors AS a, relationships AS r
         WHERE a.iri = r.from_iri
           #{common_filters(actors: "a")}
           AND r.type = '#{Relationship::Social::Follow}'
           AND r.to_iri = ?
           AND r.confirmed = 0
           AND %{cursor_condition}
      QUERY
      Actor.query_with_cursor(
        query, self.iri, cursor_column: "a.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    private def activity_count_query(type)
      <<-QUERY
         SELECT count(o.id)
           FROM objects AS o
           JOIN actors AS c
             ON c.iri = o.attributed_to_iri
           JOIN activities AS a
             ON a.object_iri = o.iri
          WHERE a.actor_iri = ?
            AND a.type = '#{type}'
            #{common_filters(objects: "o", actors: "c", activities: "a")}
            AND a.created_at > ?
      QUERY
    end

    # Translates an `Object.id` (external cursor) to the canonical
    # `activities.id` (internal cursor). Returns nil for unknown ids
    # or ids of objects that wouldn't appear in the result set.
    #
    private def translate_object_id_to_activity_id(o_id : Int64, type) : Int64?
      query = <<-QUERY
        SELECT MAX(a.id)
          FROM objects AS o
          JOIN actors AS c
            ON c.iri = o.attributed_to_iri
          JOIN activities AS a
            ON a.object_iri = o.iri
         WHERE a.actor_iri = ?
           AND a.type = '#{type}'
           AND o.id = ?
           #{common_filters(objects: "o", actors: "c", activities: "a")}
      QUERY
      Object.scalar(query, self.iri, o_id).as(Int64?)
    end

    private def activity_cursor_query(type)
      <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
           JOIN actors AS c
             ON c.iri = o.attributed_to_iri
           JOIN activities AS a
             ON a.object_iri = o.iri
          WHERE a.actor_iri = ?
            AND a.type = '#{type}'
            #{common_filters(objects: "o", actors: "c", activities: "a")}
            AND NOT EXISTS (
              SELECT 1
                FROM activities AS a2
               WHERE a2.actor_iri = a.actor_iri
                 AND a2.type = a.type
                 AND a2.undone_at IS NULL
                 AND a2.object_iri = a.object_iri
                 AND a2.id > a.id
            )
            AND %{cursor_condition}
      QUERY
    end

    # Returns the objects that this actor has liked.
    #
    # Returns the objects that this actor has liked.
    #
    # Returns objects in reverse chronological order (by when liked,
    # most recent first). Filters out deleted/blocked objects, and
    # objects by deleted/blocked actors. Also filters out likes that
    # have been undone.
    #
    def likes(*, max_id = nil, min_id = nil, limit = 10)
      max_id = translate_object_id_to_activity_id(max_id, ActivityPub::Activity::Like) if max_id
      min_id = translate_object_id_to_activity_id(min_id, ActivityPub::Activity::Like) if min_id
      Object.query_with_cursor(
        activity_cursor_query(ActivityPub::Activity::Like),
        self.iri, cursor_column: "a.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Returns the count of objects that this actor has liked since the
    # given date.
    #
    # See `#likes(max_id, min_id, limit)` for further details.
    #
    def likes(since : Time)
      Object.scalar(
        activity_count_query(ActivityPub::Activity::Like),
        iri, since,
      ).as(Int64)
    end

    # Returns the objects that this actor has disliked.
    #
    # Returns the objects that this actor has disliked.
    #
    # Returns objects in reverse chronological order (by when
    # disliked, most recent first). Filters out deleted/blocked
    # objects, and objects by deleted/blocked actors. Also filters out
    # dislikes that have been undone.
    #
    def dislikes(*, max_id = nil, min_id = nil, limit = 10)
      max_id = translate_object_id_to_activity_id(max_id, ActivityPub::Activity::Dislike) if max_id
      min_id = translate_object_id_to_activity_id(min_id, ActivityPub::Activity::Dislike) if min_id
      Object.query_with_cursor(
        activity_cursor_query(ActivityPub::Activity::Dislike),
        self.iri, cursor_column: "a.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Returns the count of objects that this actor has disliked since the
    # given date.
    #
    # See `#dislikes(max_id, min_id, limit)` for further details.
    #
    def dislikes(since : Time)
      Object.scalar(
        activity_count_query(ActivityPub::Activity::Dislike),
        iri, since,
      ).as(Int64)
    end

    # Returns the objects that this actor has announced (boosted).
    #
    # Returns the objects that this actor has announced.
    #
    # Returns objects in reverse chronological order (by when
    # announced, most recent first). Filters out deleted/blocked
    # objects, and objects by deleted/blocked actors. Also filters out
    # announces that have been undone.
    #
    def announces(*, max_id = nil, min_id = nil, limit = 10)
      max_id = translate_object_id_to_activity_id(max_id, ActivityPub::Activity::Announce) if max_id
      min_id = translate_object_id_to_activity_id(min_id, ActivityPub::Activity::Announce) if min_id
      Object.query_with_cursor(
        activity_cursor_query(ActivityPub::Activity::Announce),
        self.iri, cursor_column: "a.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Returns the count of objects that this actor has announced
    # (boosted) since the given date.
    #
    # See `#announces(max_id, min_id, limit)` for further details.
    #
    def announces(since : Time)
      Object.scalar(
        activity_count_query(ActivityPub::Activity::Announce),
        iri, since,
      ).as(Int64)
    end

    # Translates an `Object.id` (external cursor) to the canonical
    # bookmark `relationships.id` (internal cursor). Returns nil for
    # unknown ids or ids of objects that wouldn't appear in the result
    # set.
    #
    private def translate_object_id_to_bookmark_id(o_id : Int64) : Int64?
      query = <<-QUERY
        SELECT MAX(r.id)
          FROM objects AS o
          JOIN actors AS c
            ON c.iri = o.attributed_to_iri
          JOIN relationships AS r
            ON r.to_iri = o.iri
           AND r.type = '#{Relationship::Content::Bookmark}'
         WHERE r.from_iri = ?
           AND o.id = ?
           #{common_filters(objects: "o", actors: "c")}
      QUERY
      Object.scalar(query, self.iri, o_id).as(Int64?)
    end

    # Returns the objects that this actor has bookmarked.
    #
    # Returns objects in reverse chronological order (most recent
    # first). Filters out deleted/blocked objects, and objects by
    # deleted/blocked actors.
    #
    def bookmarks(*, max_id = nil, min_id = nil, limit = 10)
      max_id = translate_object_id_to_bookmark_id(max_id) if max_id
      min_id = translate_object_id_to_bookmark_id(min_id) if min_id
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
           JOIN actors AS c
             ON c.iri = o.attributed_to_iri
           JOIN relationships AS r
             ON r.to_iri = o.iri
            AND r.type = '#{Relationship::Content::Bookmark}'
          WHERE r.from_iri = ?
            #{common_filters(objects: "o", actors: "c")}
            AND %{cursor_condition}
      QUERY
      Object.query_with_cursor(query, self.iri, cursor_column: "r.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Returns the count of objects that this actor has bookmarked
    # since the given date.
    #
    # See `#bookmarks(max_id, min_id, limit)` for further details.
    #
    def bookmarks(since : Time)
      query = <<-QUERY
         SELECT count(o.id)
           FROM objects AS o
           JOIN actors AS c
             ON c.iri = o.attributed_to_iri
           JOIN relationships AS r
             ON r.to_iri = o.iri
            AND r.type = '#{Relationship::Content::Bookmark}'
          WHERE r.from_iri = ?
            #{common_filters(objects: "o", actors: "c")}
            AND r.created_at > ?
      QUERY
      Object.scalar(query, iri, since).as(Int64)
    end

    # Translates an `Object.id` (external cursor) to the canonical
    # pin `relationships.id` (internal cursor). Returns nil for
    # unknown ids or ids of objects that wouldn't appear in the result
    # set.
    #
    private def translate_object_id_to_pin_id(o_id : Int64) : Int64?
      query = <<-QUERY
        SELECT MAX(r.id)
          FROM objects AS o
          JOIN actors AS c
            ON c.iri = o.attributed_to_iri
          JOIN relationships AS r
            ON r.to_iri = o.iri
           AND r.type = '#{Relationship::Content::Pin}'
         WHERE r.from_iri = ?
           AND o.id = ?
           AND o.visible = 1
           #{common_filters(objects: "o", actors: "c")}
      QUERY
      Object.scalar(query, self.iri, o_id).as(Int64?)
    end

    # Returns the objects that this actor has pinned.
    #
    # Returns objects in reverse chronological order (most recent
    # first). Filters out deleted/blocked objects, and objects by
    # deleted/blocked actors. Does not include private (not visible)
    # posts.
    #
    def pins(*, max_id = nil, min_id = nil, limit = 10)
      max_id = translate_object_id_to_pin_id(max_id) if max_id
      min_id = translate_object_id_to_pin_id(min_id) if min_id
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
           JOIN actors AS c
             ON c.iri = o.attributed_to_iri
           JOIN relationships AS r
             ON r.to_iri = o.iri
            AND r.type = '#{Relationship::Content::Pin}'
          WHERE r.from_iri = ?
            #{common_filters(objects: "o", actors: "c")}
            AND o.visible = 1
            AND %{cursor_condition}
      QUERY
      Object.query_with_cursor(query, self.iri, cursor_column: "r.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Returns the count of objects that this actor has pinned since the
    # given date.
    #
    # See `#pins(max_id, min_id, limit)` for further details.
    #
    def pins(since : Time)
      query = <<-QUERY
         SELECT count(o.id)
           FROM objects AS o
           JOIN actors AS c
             ON c.iri = o.attributed_to_iri
           JOIN relationships AS r
             ON r.to_iri = o.iri
            AND r.type = '#{Relationship::Content::Pin}'
          WHERE r.from_iri = ?
            #{common_filters(objects: "o", actors: "c")}
            AND o.visible = 1
            AND r.created_at > ?
      QUERY
      Object.scalar(query, self.iri, since).as(Int64)
    end

    # Returns the actor's draft posts.
    #
    # Meant to be called on local (not cached) actors.
    #
    # Includes only unpublished posts attributed to this actor.
    #
    def drafts(*, max_id = nil, min_id = nil, limit = 10)
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
          WHERE o.attributed_to_iri = ?
            AND o.published IS NULL
            #{common_filters(objects: "o")}
            AND %{cursor_condition}
      QUERY
      Object.query_with_cursor(query, iri, cursor_column: "o.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Returns the count of the actor's drafts since the given date.
    #
    # See `#drafts(max_id, min_id, limit)` for further details.
    #
    def drafts(since : Time)
      query = <<-QUERY
         SELECT count(o.id)
           FROM objects AS o
          WHERE o.attributed_to_iri = ?
            AND o.published IS NULL
            #{common_filters(objects: "o")}
            AND o.created_at > ?
      QUERY
      Object.scalar(query, iri, since).as(Int64)
    end

    # Returns mailbox contents with cursor-based pagination.
    #
    # The cursor column is the mailbox `relationships.id` rather than
    # the activity id so the collection stays ordered by when each
    # activity arrived in the mailbox. Externally the cursor is the
    # activity id; the translation helper converts at the input
    # boundary.
    #
    protected def self.content(iri, mailbox, inclusion = nil, exclusion = nil, *, max_id = nil, min_id = nil, limit = 10, public = true, replies = true)
      mailbox =
        case mailbox
        when Class
          %Q|AND r.type = '#{mailbox}'|
        when Array
          %Q|AND r.type IN ('#{mailbox.map(&.to_s).join("','")}')|
        end
      inclusion =
        case inclusion
        when Class
          %Q|AND a.type = '#{inclusion}'|
        when Array
          %Q|AND a.type IN ('#{inclusion.map(&.to_s).join("','")}')|
        end
      exclusion =
        case exclusion
        when Class
          %Q|AND a.type != '#{exclusion}'|
        when Array
          %Q|AND a.type NOT IN ('#{exclusion.map(&.to_s).join("','")}')|
        end
      max_id = translate_activity_id_to_relationship_id(iri, mailbox, inclusion, exclusion, max_id, public, replies) if max_id
      min_id = translate_activity_id_to_relationship_id(iri, mailbox, inclusion, exclusion, min_id, public, replies) if min_id
      query = <<-QUERY
         SELECT #{Activity.columns(prefix: "a")}, #{Object.columns(prefix: "obj")}
           FROM activities AS a
           JOIN relationships AS r
             ON r.to_iri = a.iri
      LEFT JOIN actors AS act
             ON act.iri = a.actor_iri
      LEFT JOIN objects AS obj
             ON obj.iri = a.object_iri
          WHERE r.from_iri LIKE ?
            #{mailbox}
            AND r.confirmed = 1
            #{Actor.common_filters(actors: "act", objects: "obj", activities: "a")}
            #{inclusion}
            #{exclusion}
       #{public ? %Q|AND a.visible = 1| : nil}
       #{!replies ? %Q|AND obj.in_reply_to_iri IS NULL| : nil}
            AND %{cursor_condition}
      QUERY
      Activity.query_with_cursor(query, iri, cursor_column: "r.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Translates an `Activity.id` (external cursor) to the canonical
    # mailbox `relationships.id` (internal cursor). Returns nil for
    # unknown ids or ids of activities that wouldn't appear in the
    # result set.
    #
    private def self.translate_activity_id_to_relationship_id(iri, mailbox, inclusion, exclusion, a_id, public, replies) : Int64?
      query = <<-QUERY
         SELECT MAX(r.id)
           FROM activities AS a
           JOIN relationships AS r
             ON r.to_iri = a.iri
      LEFT JOIN actors AS act
             ON act.iri = a.actor_iri
      LEFT JOIN objects AS obj
             ON obj.iri = a.object_iri
          WHERE r.from_iri LIKE ?
            AND a.id = ?
            #{mailbox}
            AND r.confirmed = 1
            #{Actor.common_filters(actors: "act", objects: "obj", activities: "a")}
            #{inclusion}
            #{exclusion}
       #{public ? %Q|AND a.visible = 1| : nil}
       #{!replies ? %Q|AND obj.in_reply_to_iri IS NULL| : nil}
      QUERY
      Activity.scalar(query, iri, a_id).as(Int64?)
    end

    private def find_in?(object, mailbox, inclusion = nil, exclusion = nil)
      mailbox =
        case mailbox
        when Class
          %Q|AND r.type = '#{mailbox}'|
        when Array
          %Q|AND r.type IN ('#{mailbox.map(&.to_s).join("','")}')|
        end
      inclusion =
        case inclusion
        when Class
          %Q|AND a.type = '#{inclusion}'|
        when Array
          %Q|AND a.type IN ('#{inclusion.map(&.to_s).join("','")}')|
        end
      exclusion =
        case exclusion
        when Class
          %Q|AND a.type != '#{exclusion}'|
        when Array
          %Q|AND a.type NOT IN ('#{exclusion.map(&.to_s).join("','")}')|
        end
      query = <<-QUERY
         SELECT count(a.id)
           FROM activities AS a
           JOIN relationships AS r
             ON r.to_iri = a.iri
           JOIN actors AS act
             ON act.iri = a.actor_iri
           JOIN objects AS obj
             ON obj.iri = a.object_iri
          WHERE r.from_iri = ?
            AND obj.iri = ?
            #{mailbox}
            AND r.confirmed = 1
            #{common_filters(actors: "act", objects: "obj", activities: "a")}
            #{inclusion}
            #{exclusion}
      QUERY
      Activity.scalar(query, self.iri, object.iri).as(Int64) > 0
    end

    def in_outbox(*, max_id = nil, min_id = nil, limit = 10, public = true)
      self.class.content(self.iri, Relationship::Content::Outbox, nil, [ActivityPub::Activity::Delete, ActivityPub::Activity::Undo], max_id: max_id, min_id: min_id, limit: limit, public: public)
    end

    def in_outbox?(object : Object, inclusion = nil, exclusion = nil)
      find_in?(object, Relationship::Content::Outbox, inclusion, exclusion)
    end

    def in_inbox(*, max_id = nil, min_id = nil, limit = 10, public = true)
      self.class.content(self.iri, Relationship::Content::Inbox, nil, [ActivityPub::Activity::Delete, ActivityPub::Activity::Undo], max_id: max_id, min_id: min_id, limit: limit, public: public)
    end

    def in_inbox?(object : Object, inclusion = nil, exclusion = nil)
      find_in?(object, Relationship::Content::Inbox, inclusion, exclusion)
    end

    def find_activity_for(object, inclusion = nil, exclusion = nil)
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
           JOIN actors AS act
             ON act.iri = a.actor_iri
           JOIN objects AS obj
             ON obj.iri = a.object_iri
          WHERE a.actor_iri = ?
            AND a.object_iri = ?
            #{common_filters(actors: "act", objects: "obj", activities: "a")}
            #{inclusion}
            #{exclusion}
      QUERY
      Activity.query_all(query, self.iri, object.iri).first?
    end

    def find_announce_for(object : Object)
      find_activity_for(object, ActivityPub::Activity::Announce)
    end

    def find_like_for(object : Object)
      find_activity_for(object, ActivityPub::Activity::Like)
    end

    # Returns the SQL fragment and bound arguments for excluding
    # pinned objects. The SQL references `o` as the object alias; call
    # sites must alias `objects AS o`.
    #
    private def pin_exclusion_clause(exclude_pinned : Bool) : {String, Array(::DB::Any)}
      if exclude_pinned
        {
          "AND NOT EXISTS (SELECT 1 FROM relationships AS p WHERE p.type = '#{Relationship::Content::Pin}' AND p.from_iri = ? AND p.to_iri = o.iri)",
          [self.iri] of ::DB::Any,
        }
      else
        {"", [] of ::DB::Any}
      end
    end

    # Translates an `Object.id` (external cursor) to its
    # `(published, id)` tuple (internal cursor for `known_posts`).
    # Returns nil for unknown / invalid ids so the caller falls
    # back to the first page.
    #
    private def translate_object_id_to_published_and_id(o_id : Int64, exclude_pinned = false) : {Time, Int64}?
      pin_filter, pin_args = pin_exclusion_clause(exclude_pinned)
      query = <<-QUERY
        SELECT o.published, o.id
          FROM objects AS o
         WHERE o.attributed_to_iri = ?
           AND o.id = ?
           #{common_filters(objects: "o")}
           AND o.published IS NOT NULL
           AND o.visible = 1
           #{pin_filter}
      QUERY
      args = [self.iri, o_id] of ::DB::Any
      args.concat(pin_args)
      Ktistec.database.query_one?(query, args: args) do |rs|
        {rs.read(Time), rs.read(Int64)}
      end
    end

    # Returns the actor's known posts.
    #
    # Returns the actor's known posts.
    #
    # Meant to be called on both local and cached actors.
    #
    # Orders by publication time (most recent first).
    #
    # Does not include private (not visible) posts.
    #
    # Includes pinned posts, by default.
    #
    def known_posts(*, max_id = nil, min_id = nil, limit = 10, exclude_pinned = false)
      max_cursor = max_id ? translate_object_id_to_published_and_id(max_id, exclude_pinned: exclude_pinned) : nil
      min_cursor = min_id ? translate_object_id_to_published_and_id(min_id, exclude_pinned: exclude_pinned) : nil

      pin_filter, pin_args = pin_exclusion_clause(exclude_pinned)

      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
          WHERE o.attributed_to_iri = ?
            #{common_filters(objects: "o")}
            AND o.published IS NOT NULL
            AND o.visible = 1
            #{pin_filter}
            AND %{cursor_condition}
      QUERY

      args = [self.iri] of ::DB::Any
      args.concat(pin_args)

      Object.query_with_keyset_cursor(query, cursor_columns: {"o.published", "o.id"}, max_cursor: max_cursor, min_cursor: min_cursor, limit: limit, args: args)
    end

    # Returns the actor's pinned posts.
    #
    # Meant to be called on both local and cached actors.
    #
    def pinned_posts
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
           JOIN relationships AS p
             ON p.type = '#{Relationship::Content::Pin}'
            AND p.from_iri = ?
            AND p.to_iri = o.iri
          WHERE o.attributed_to_iri = ?
            #{common_filters(objects: "o")}
            AND o.published IS NOT NULL
            AND o.visible = 1
       ORDER BY p.id DESC
      QUERY
      Object.query_all(query, self.iri, self.iri)
    end

    # Translates an `Object.id` (external cursor) to the canonical
    # outbox `relationships.id` (internal cursor), additionally
    # restricted to visible, non-reply objects. Returns nil for
    # unknown ids.
    #
    private def translate_object_id_to_public_outbox_id(o_id : Int64, exclude_pinned = false) : Int64?
      pin_filter, pin_args = pin_exclusion_clause(exclude_pinned)
      query = <<-QUERY
        SELECT MAX(r.id)
          FROM objects AS o
          JOIN actors AS t
            ON t.iri = o.attributed_to_iri
          JOIN activities AS a
            ON a.object_iri = o.iri
           AND a.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
          JOIN relationships AS r
            ON r.to_iri = a.iri
           AND r.type = '#{Relationship::Content::Outbox}'
         WHERE r.from_iri = ?
           AND o.id = ?
           AND o.visible = 1
           AND o.in_reply_to_iri IS NULL
           #{common_filters(objects: "o", actors: "t", activities: "a")}
           #{pin_filter}
      QUERY
      args = [self.iri, o_id] of ::DB::Any
      args.concat(pin_args)
      Object.scalar(query, args: args).as(Int64?)
    end

    # Translates an `Object.id` (external cursor) to the canonical
    # outbox `relationships.id` (internal cursor). Returns nil for
    # unknown ids.
    #
    private def translate_object_id_to_outbox_id(o_id : Int64) : Int64?
      query = <<-QUERY
        SELECT MAX(r.id)
          FROM objects AS o
          JOIN actors AS t
            ON t.iri = o.attributed_to_iri
          JOIN activities AS a
            ON a.object_iri = o.iri
           AND a.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
          JOIN relationships AS r
            ON r.to_iri = a.iri
           AND r.type = '#{Relationship::Content::Outbox}'
         WHERE r.from_iri = ?
           AND o.id = ?
           #{common_filters(objects: "o", actors: "t", activities: "a")}
      QUERY
      Object.scalar(query, self.iri, o_id).as(Int64?)
    end

    # Returns the actor's public posts and shares.
    #
    # Meant to be called on local (not cached) actors.
    #
    # Does not include private (not visible) posts and replies.
    #
    def public_posts(*, max_id = nil, min_id = nil, limit = 10, exclude_pinned = false)
      max_id = translate_object_id_to_public_outbox_id(max_id, exclude_pinned) if max_id
      min_id = translate_object_id_to_public_outbox_id(min_id, exclude_pinned) if min_id
      pin_filter, pin_args = pin_exclusion_clause(exclude_pinned)
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
           JOIN actors AS t
             ON t.iri = o.attributed_to_iri
           JOIN activities AS a
             ON a.object_iri = o.iri
            AND a.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
           JOIN relationships AS r
             ON r.to_iri = a.iri
            AND r.type = '#{Relationship::Content::Outbox}'
          WHERE r.from_iri = ?
            #{common_filters(objects: "o", actors: "t", activities: "a")}
            AND likelihood(o.in_reply_to_iri IS NULL, 0.25)
            AND o.visible = 1
            AND NOT EXISTS (
              SELECT 1
                FROM relationships AS r2
                JOIN activities AS a2 ON a2.iri = r2.to_iri
               WHERE r2.from_iri = r.from_iri
                 AND r2.type = '#{Relationship::Content::Outbox}'
                 AND a2.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
                 AND a2.undone_at IS NULL
                 AND a2.object_iri = a.object_iri
                 AND r2.id > r.id
            )
            #{pin_filter}
            AND %{cursor_condition}
      QUERY
      args = [self.iri] of ::DB::Any
      args.concat(pin_args)
      Object.query_with_cursor(query, args: args, cursor_column: "r.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Returns the actor's posts and shares.
    #
    # Meant to be called on local (not cached) actors.
    #
    # Includes private posts and replies!
    #
    def all_posts(*, max_id = nil, min_id = nil, limit = 10)
      max_id = translate_object_id_to_outbox_id(max_id) if max_id
      min_id = translate_object_id_to_outbox_id(min_id) if min_id
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
           JOIN actors AS t
             ON t.iri = o.attributed_to_iri
           JOIN activities AS a
             ON a.object_iri = o.iri
            AND a.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
           JOIN relationships AS r
             ON r.to_iri = a.iri
            AND r.type = '#{Relationship::Content::Outbox}'
          WHERE r.from_iri = ?
            #{common_filters(objects: "o", actors: "t", activities: "a")}
            AND NOT EXISTS (
              SELECT 1
                FROM relationships AS r2
                JOIN activities AS a2 ON a2.iri = r2.to_iri
               WHERE r2.from_iri = r.from_iri
                 AND r2.type = '#{Relationship::Content::Outbox}'
                 AND a2.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
                 AND a2.undone_at IS NULL
                 AND a2.object_iri = a.object_iri
                 AND r2.id > r.id
            )
            AND %{cursor_condition}
      QUERY
      Object.query_with_cursor(query, self.iri, cursor_column: "r.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    # Returns the count of the actor's posts since the given date.
    #
    # See `#all_posts(max_id, min_id, limit)` for further details.
    #
    def all_posts(since : Time)
      query = <<-QUERY
         SELECT count(r.id)
           FROM objects AS o
           JOIN actors AS t
             ON t.iri = o.attributed_to_iri
           JOIN activities AS a
             ON a.object_iri = o.iri
            AND a.type IN ('#{ActivityPub::Activity::Announce}', '#{ActivityPub::Activity::Create}')
           JOIN relationships AS r
             ON r.to_iri = a.iri
            AND r.type = '#{Relationship::Content::Outbox}'
          WHERE r.from_iri = ?
            #{common_filters(objects: "o", actors: "t", activities: "a")}
            AND r.created_at > ?
      QUERY
      Relationship::Content::Outbox.scalar(query, iri, since).as(Int64)
    end

    private alias Timeline = Relationship::Content::Timeline

    # Translates an `Object.id` (external cursor) to the canonical
    # timeline `relationships.id` (internal cursor). Returns nil for
    # unknown ids or ids of objects that wouldn't appear in the result
    # set.
    #
    private def translate_object_id_to_timeline_id(o_id : Int64, type_list : String, exclude_replies : Bool) : Int64?
      exclude_replies_clause =
        exclude_replies ? "AND o.in_reply_to_iri IS NULL" : ""
      query = <<-QUERY
        SELECT MAX(t.id)
          FROM relationships AS t
          JOIN objects AS o
            ON o.iri = t.to_iri
          JOIN actors AS c
            ON c.iri = o.attributed_to_iri
         WHERE t.from_iri = ?
           AND t.type IN (#{type_list})
           AND o.id = ?
           #{exclude_replies_clause}
           #{common_filters(objects: "o", actors: "c")}
      QUERY
      Timeline.scalar(query, self.iri, o_id).as(Int64?)
    end

    # Returns entries in the actor's timeline.
    #
    # Meant to be called on local (not cached) actors.
    #
    # Includes private (not visible) posts and replies.
    #
    # May be filtered to exclude replies (via `exclude_replies`).
    #
    # May be filtered to include only objects with associated
    # relationships of the specified type (via `inclusion`).
    #
    def timeline(*, exclude_replies = false, inclusion = nil, max_id = nil, min_id = nil, limit = 10)
      inclusion_types =
        case inclusion
        when Class, String
          [inclusion.to_s]
        when Array
          inclusion.map(&.to_s)
        else
          Timeline.all_subtypes.map(&.to_s)
        end
      type_list = "'#{inclusion_types.join("','")}'"
      exclude_replies_clause =
        exclude_replies ? "AND likelihood(o.in_reply_to_iri IS NULL, 0.25)" : ""
      max_id = translate_object_id_to_timeline_id(max_id, type_list, exclude_replies) if max_id
      min_id = translate_object_id_to_timeline_id(min_id, type_list, exclude_replies) if min_id
      query = <<-QUERY
          SELECT #{Timeline.columns(prefix: "t")}
            FROM relationships AS t
            JOIN objects AS o
              ON o.iri = t.to_iri
            JOIN actors AS c
              ON c.iri = o.attributed_to_iri
           WHERE +t.from_iri = ?
             AND +t.type IN (#{type_list})
             #{exclude_replies_clause}
             #{common_filters(objects: "o", actors: "c")}
             AND NOT EXISTS (
               SELECT 1
                 FROM relationships AS t2
                WHERE t2.from_iri = t.from_iri
                  AND t2.type IN (#{type_list})
                  AND t2.to_iri = t.to_iri
                  AND t2.id > t.id
             )
             AND %{cursor_condition}
      QUERY
      result = Timeline.query_with_cursor(query, self.iri, cursor_column: "t.id", max_id: max_id, min_id: min_id, limit: limit)
      unless result.empty?
        result.cursor_start = result.first.object.id
        result.cursor_end = result.to_a.last.object.id
      end
      result
    end

    # Returns the count of entries in the actor's timeline since the
    # given date.
    #
    # See `#timeline(exclude_replies, inclusion, max_id, min_id, limit)` for further details.
    #
    def timeline(since : Time, exclude_replies = false, inclusion = nil)
      exclude_replies =
        exclude_replies ? "AND likelihood(o.in_reply_to_iri IS NULL, 0.25)" : ""
      inclusion =
        case inclusion
        when Class, String
          %Q|AND +t.type = '#{inclusion}'|
        when Array
          %Q|AND +t.type IN ('#{inclusion.map(&.to_s).join("','")}')|
        else
          %Q|AND +t.type IN ('#{Timeline.all_subtypes.map(&.to_s).join("','")}')|
        end
      query = <<-QUERY
          SELECT count(t.id)
            FROM relationships AS t
            JOIN objects AS o
              ON o.iri = t.to_iri
            JOIN actors AS c
              ON c.iri = o.attributed_to_iri
           WHERE +t.from_iri = ?
             #{inclusion}
             #{exclude_replies}
             #{common_filters(objects: "o", actors: "c")}
             AND t.created_at > ?
      QUERY
      Timeline.scalar(query, iri, since).as(Int64)
    end

    private alias Notification = Relationship::Content::Notification

    # Translates an externally-supplied notification id into the
    # notification row's `(created_at, id)` cursor pair. Returns nil for
    # unknown ids or ids not in the actor's notifications.
    #
    private def translate_notification_id_to_created_at_and_id(n_id : Int64) : {Time, Int64}?
      query = <<-QUERY
        SELECT n.created_at, n.id
          FROM relationships AS n
         WHERE n.from_iri = ?
           AND n.id = ?
           AND n.type IN ('#{Notification.all_subtypes.map(&.to_s).join("','")}')
      QUERY
      Ktistec.database.query_one?(query, iri, n_id, as: {Time, Int64})
    end

    # Returns notifications for the actor.
    #
    # Meant to be called on local (not cached) actors.
    #
    def notifications(*, max_id = nil, min_id = nil, limit = 10)
      max_cursor = translate_notification_id_to_created_at_and_id(max_id) if max_id
      min_cursor = translate_notification_id_to_created_at_and_id(min_id) if min_id
      query = <<-QUERY
         SELECT #{Notification.columns(prefix: "n")}
           FROM relationships AS n
      LEFT JOIN activities AS a
             ON a.iri = n.to_iri
      LEFT JOIN actors AS c
             ON c.iri = a.actor_iri
      LEFT JOIN objects AS o
             ON o.iri = a.object_iri
      LEFT JOIN objects AS e
             ON e.iri = n.to_iri
      LEFT JOIN actors AS t
             ON t.iri = e.attributed_to_iri
          WHERE +n.from_iri = ?
            AND n.type IN ('#{Notification.all_subtypes.map(&.to_s).join("','")}')
            #{common_filters(actors: "c", objects: "o", activities: "a")}
            #{common_filters(objects: "e", actors: "t")}
            AND %{cursor_condition}
      QUERY
      Notification.query_with_keyset_cursor(query, iri, cursor_columns: {"n.created_at", "n.id"}, max_cursor: max_cursor, min_cursor: min_cursor, limit: limit)
    end

    # Returns the count of notifications for the actor since the given
    # date.
    #
    # See `#notifications(max_id, min_id, limit)` for further details.
    #
    def notifications(since : Time)
      query = <<-QUERY
         SELECT count(*)
           FROM relationships AS n
      LEFT JOIN activities AS a
             ON a.iri = n.to_iri
      LEFT JOIN actors AS c
             ON c.iri = a.actor_iri
      LEFT JOIN objects AS o
             ON o.iri = a.object_iri
      LEFT JOIN objects AS e
             ON e.iri = n.to_iri
      LEFT JOIN actors AS t
             ON t.iri = e.attributed_to_iri
          WHERE +n.from_iri = ?
            AND n.type IN ('#{Notification.all_subtypes.map(&.to_s).join("','")}')
            #{common_filters(actors: "c", objects: "o", activities: "a")}
            #{common_filters(objects: "e", actors: "t")}
            AND n.created_at > ?
      QUERY
      Notification.scalar(query, iri, since).as(Int64)
    end

    def approve(object)
      to_iri = object.responds_to?(:iri) ? object.iri : object.to_s
      unless Relationship::Content::Approved.count(from_iri: iri, to_iri: to_iri) > 0
        Relationship::Content::Approved.new(from_iri: iri, to_iri: to_iri).save
      end
    end

    def unapprove(object)
      to_iri = object.responds_to?(:iri) ? object.iri : object.to_s
      if (approved = Relationship::Content::Approved.find?(from_iri: iri, to_iri: to_iri))
        approved.destroy
      end
    end

    # Returns the content filter terms for the actor.
    #
    def terms(*, max_id = nil, min_id = nil, limit = 10)
      query = <<-QUERY
         SELECT #{FilterTerm.columns(prefix: "f")}
           FROM filter_terms AS f
          WHERE f.actor_id = ?
            AND %{cursor_condition}
      QUERY
      FilterTerm.query_with_cursor(query, id, cursor_column: "f.id", max_id: max_id, min_id: min_id, limit: limit)
    end

    getter followed_actors : Set(String) do
      query = <<-QUERY
         SELECT r.to_iri
           FROM relationships AS r
          WHERE r.type = '#{Relationship::Social::Follow}'
            AND r.from_iri = ?
            AND r.confirmed = 1
      QUERY
      Ktistec.database.query_all(query, iri, as: String).to_set
    end

    getter followed_hashtags : Set(String) do
      query = <<-QUERY
         SELECT r.to_iri
           FROM relationships AS r
          WHERE r.type = '#{Relationship::Content::Follow::Hashtag}'
            AND r.from_iri = ?
      QUERY
      Ktistec.database.query_all(query, iri, as: String).map(&.downcase).to_set
    end

    getter followed_mentions : Set(String) do
      query = <<-QUERY
         SELECT r.to_iri
           FROM relationships AS r
          WHERE r.type = '#{Relationship::Content::Follow::Mention}'
            AND r.from_iri = ?
      QUERY
      Ktistec.database.query_all(query, iri, as: String).to_set
    end

    def make_delete_activity
      ActivityPub::Activity::Delete.new(
        iri: "#{Ktistec.host}/activities/#{Ktistec::Util.id}",
        actor: self,
        object: self,
        to: ["https://www.w3.org/ns/activitystreams#Public"],
        cc: [followers, following].compact,
      )
    end

    def to_json_ld(recursive = true)
      ActorModelHelper.to_json_ld(self, recursive)
    end

    def from_json_ld(json, *, include_key = false)
      self.assign(self.class.map(json, include_key: include_key))
    end

    def self.map(json, *, include_key = false, **options)
      ActorModelHelper.from_json_ld(json, include_key)
    end
  end
end

private module ActorModelHelper
  include Ktistec::ViewHelper

  def self.to_json_ld(actor, recursive)
    render "src/views/actors/actor.json.ecr"
  end

  def self.from_json_ld(json : JSON::Any | String | IO, include_key)
    json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
    {
      "iri"            => json.dig?("@id").try(&.as_s),
      "_type"          => json.dig?("@type").try(&.as_s.split("#").last),
      "username"       => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#preferredUsername"),
      "pem_public_key" => if include_key
        Ktistec::JSON_LD.dig?(json, "https://w3id.org/security#publicKey", "https://w3id.org/security#publicKeyPem")
      end,
      "shared_inbox" => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#endpoints", "https://www.w3.org/ns/activitystreams#sharedInbox"),
      "inbox"        => Ktistec::JSON_LD.dig_id?(json, "http://www.w3.org/ns/ldp#inbox"),
      "outbox"       => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#outbox"),
      "following"    => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#following"),
      "followers"    => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#followers"),
      "featured"     => Ktistec::JSON_LD.dig_id?(json, "http://joinmastodon.org/ns#featured"),
      "name"         => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#name", "und"),
      "summary"      => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#summary", "und"),
      "icon"         => map_icon?(json, "https://www.w3.org/ns/activitystreams#icon"),
      "image"        => map_icon?(json, "https://www.w3.org/ns/activitystreams#image"),
      "urls"         => Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#url"),
      "attachments"  => Ktistec::JSON_LD.dig_values?(json, "https://www.w3.org/ns/activitystreams#attachment") do |attachment|
        name = Ktistec::JSON_LD.dig?(attachment, "https://www.w3.org/ns/activitystreams#name", "und").presence
        type = Ktistec::JSON_LD.dig?(attachment, "@type").presence
        value = (
          Ktistec::JSON_LD.dig?(attachment, "http://schema.org#value") || # Mastodon and our own output
          Ktistec::JSON_LD.dig?(attachment, "http://schema.org/value")    # Mitra and schema.org's own canonical context
        ).presence
        ActivityPub::Actor::Attachment.new(name, type, value) if name && type && value
      end,
      "emojis" => Ktistec::JSON_LD.dig_values?(json, "https://www.w3.org/ns/activitystreams#tag") do |tag|
        next unless tag.dig?("@type") == "http://joinmastodon.org/ns#Emoji"
        name = Ktistec::JSON_LD.dig?(tag, "https://www.w3.org/ns/activitystreams#name", "und").presence
        icon_url = tag.dig?("https://www.w3.org/ns/activitystreams#icon", "https://www.w3.org/ns/activitystreams#url").try(&.as_s?)
        Tag::Emoji.new(name: name, href: icon_url) if name && icon_url
      end,
    }.compact
  end

  def self.map_icon?(json, *selector)
    json.dig?(*selector).try do |icons|
      if icons.as_a?
        icon =
          icons.as_a.map do |ico|
            if (width = ico.dig?("https://www.w3.org/ns/activitystreams#width")) && (height = ico.dig?("https://www.w3.org/ns/activitystreams#height"))
              {width.as_i * height.as_i, ico}
            else
              {0, ico}
            end
          end.sort! do |(a, _), (b, _)|
            b <=> a
          end.first?
        if icon
          icon[1].dig?("https://www.w3.org/ns/activitystreams#url").try(&.as_s?)
        end
      elsif icons
        icons.dig?("https://www.w3.org/ns/activitystreams#url").try(&.as_s?)
      end
    end
  end
end
