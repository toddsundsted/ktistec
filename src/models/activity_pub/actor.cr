require "json"
require "openssl_ext"

require "../../framework/util"
require "../../framework/json_ld"
require "../../framework/key_pair"
require "../../framework/ext/sqlite3"
require "../../framework/model"
require "../../framework/model/**"
require "../activity_pub"
require "../activity_pub/mixins/blockable"
require "../relationship/content/approved"
require "../relationship/content/notification/*"
require "../relationship/content/timeline/*"
require "../relationship/content/inbox"
require "../relationship/content/outbox"
require "../relationship/social/follow"
require "../filter_term"
require "./activity"
require "./activity/announce"
require "./activity/create"
require "./activity/delete"
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

    ATTACHMENT_LIMIT = 4

    @@table_name = "actors"

    ALIASES = [
      "Application",
      "Group",
      "Organization",
      "Service",
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
    property inbox : String?

    @[Persistent]
    property outbox : String?

    @[Persistent]
    property following : String?

    @[Persistent]
    property followers : String?

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

    has_many filter_terms, inverse_of: actor

    # the implementation of attachments follows Mastodon's design

    struct Attachment
      include JSON::Serializable

      property name : String

      property type : String

      property value : String

      def initialize(@name, @type, @value)
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
          self.urls = ["#{host}/@#{username}"]
        end
      end
    end

    def handle
      blocked? ? "[blocked]" : %Q|#{username}@#{URI.parse(iri).host}|
    end

    def display_name
      blocked? ? "[blocked]" : (name.presence || username.presence || iri)
    end

    def display_link
      urls.try(&.first?) || iri
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
      !other.deleted? && !other.blocked? ?
        Relationship::Social::Follow.find?(**options.merge({actor: self, object: other})) :
        nil
    end

    # Adds common filters to a query.
    #
    # The `first_prefix` and `second_prefix` can be either actor or
    # object table names.
    #
    macro common_filters_on(first_prefix = nil, second_prefix = nil, activity_prefix = nil)
      <<-QUERY
        {% if first_prefix %}
          AND {{first_prefix}}.deleted_at IS NULL
          AND {{first_prefix}}.blocked_at IS NULL
        {% end %}
        {% if second_prefix %}
          AND {{second_prefix}}.deleted_at IS NULL
          AND {{second_prefix}}.blocked_at IS NULL
        {% end %}
        {% if activity_prefix %}
          AND {{activity_prefix}}.undone_at IS NULL
        {% end %}
      QUERY
    end

    private def social_query(type, orig, dest, public = true)
      public = public ? "AND r.confirmed = 1 AND r.visible = 1" : nil
      query = <<-QUERY
        SELECT #{Actor.columns(prefix: "a")}
          FROM actors AS a, relationships AS r
         WHERE a.iri = r.#{orig}
           #{common_filters_on("a")}
           AND r.type = '#{type}'
           AND r.#{dest} = ?
           #{public}
      ORDER BY r.id DESC
         LIMIT ? OFFSET ?
      QUERY
    end

    def all_following(page = 1, size = 10, public = true)
      Actor.query_and_paginate(
        social_query(Relationship::Social::Follow, :to_iri, :from_iri, public),
        self.iri, page: page, size: size
      )
    end

    def all_followers(page = 1, size = 10, public = false)
      Actor.query_and_paginate(
        social_query(Relationship::Social::Follow, :from_iri, :to_iri, public),
        self.iri, page: page, size: size
      )
    end

    private def activity_query(type)
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
           JOIN actors AS c
             ON c.iri = o.attributed_to_iri
           JOIN activities AS a
             ON a.object_iri = o.iri
          WHERE a.actor_iri = ?
            AND a.type = '#{type}'
            #{common_filters_on("o", "c", "a")}
       ORDER BY o.id DESC
          LIMIT ? OFFSET ?
      QUERY
    end

    def likes(page = 1, size = 10)
      Object.query_and_paginate(
        activity_query(ActivityPub::Activity::Like),
        self.iri, page: page, size: size
      )
    end

    def announces(page = 1, size = 10)
      Object.query_and_paginate(
        activity_query(ActivityPub::Activity::Announce),
        self.iri, page: page, size: size
      )
    end

    # Returns the actor's draft posts.
    #
    # Meant to be called on local (not cached) actors.
    #
    # Includes only unpublished posts attributed to this actor.
    #
    def drafts(page = 1, size = 10)
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
          WHERE o.attributed_to_iri = ?
            AND o.published IS NULL
            #{common_filters_on("o")}
       ORDER BY o.id DESC
          LIMIT ? OFFSET ?
      QUERY
      Object.query_and_paginate(query, iri, page: page, size: size)
    end

    # Returns the count of the actor's drafts since the given date.
    #
    # See `#drafts(page, size)` for further details.
    #
    def drafts(since : Time)
      query = <<-QUERY
         SELECT count(o.id)
           FROM objects AS o
          WHERE o.attributed_to_iri = ?
            AND o.published IS NULL
            #{common_filters_on("o")}
            AND o.created_at > ?
      QUERY
      Object.scalar(query, iri, since).as(Int64)
    end

    protected def self.content(iri, mailbox, inclusion = nil, exclusion = nil, page = 1, size = 10, public = true, replies = true)
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
            #{inclusion}
            #{exclusion}
            #{Actor.common_filters_on("act", "obj", "a")}
       #{public ? %Q|AND a.visible = 1| : nil}
       #{!replies ? %Q|AND obj.in_reply_to_iri IS NULL| : nil}
       ORDER BY r.id DESC
          LIMIT ? OFFSET ?
      QUERY
      Activity.query_and_paginate(query, iri, page: page, size: size)
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
            #{inclusion}
            #{exclusion}
            #{common_filters_on("act", "obj", "a")}
      QUERY
      Activity.scalar(query, self.iri, object.iri).as(Int64) > 0
    end

    def in_outbox(page = 1, size = 10, public = true)
      self.class.content(self.iri, Relationship::Content::Outbox, nil, [ActivityPub::Activity::Delete, ActivityPub::Activity::Undo], page, size, public)
    end

    def in_outbox?(object : Object, inclusion = nil, exclusion = nil)
      find_in?(object, Relationship::Content::Outbox, inclusion, exclusion)
    end

    def in_inbox(page = 1, size = 10, public = true)
      self.class.content(self.iri, Relationship::Content::Inbox, nil, [ActivityPub::Activity::Delete, ActivityPub::Activity::Undo], page, size, public)
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
            #{inclusion}
            #{exclusion}
            #{common_filters_on("act", "obj", "a")}
      QUERY
      Activity.query_all(query, self.iri, object.iri).first?
    end

    def find_announce_for(object : Object)
      find_activity_for(object, ActivityPub::Activity::Announce)
    end

    def find_like_for(object : Object)
      find_activity_for(object, ActivityPub::Activity::Like)
    end

    # Returns the actor's known posts.
    #
    # Meant to be called on both local and cached actors.
    #
    # Does not include private (not visible) posts.
    #
    def known_posts(page = 1, size = 10)
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
          WHERE o.attributed_to_iri = ?
            AND o.visible = 1
            AND o.deleted_at is NULL
            AND o.blocked_at is NULL
       ORDER BY o.published DESC
          LIMIT ? OFFSET ?
      QUERY
      Object.query_and_paginate(query, self.iri, page: page, size: size)
    end

    # Returns the actor's public posts.
    #
    # Meant to be called on local (not cached) actors.
    #
    # Does not include private (not visible) posts and replies.
    #
    def public_posts(page = 1, size = 10)
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
            AND o.visible = 1
            AND likelihood(o.in_reply_to_iri IS NULL, 0.25)
            #{common_filters_on("o", "t", "a")}
       ORDER BY r.id DESC
          LIMIT ? OFFSET ?
      QUERY
      Object.query_and_paginate(query, self.iri, page: page, size: size)
    end

    # Returns an actor's own posts
    #
    # Meant to be called on local (not cached) actors.
    #
    # Includes private posts and replies!
    #
    def all_posts(page = 1, size = 10)
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
            #{common_filters_on("o", "t", "a")}
       ORDER BY r.id DESC
          LIMIT ? OFFSET ?
      QUERY
      Object.query_and_paginate(query, self.iri, page: page, size: size)
    end

    # Returns the count of the actor's posts since the given date.
    #
    # See `#all_posts(page, size)` for further details.
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
            #{common_filters_on("o", "t", "a")}
            AND r.created_at > ?
      QUERY
      Relationship::Content::Outbox.scalar(query, iri, since).as(Int64)
    end

    private alias Timeline = Relationship::Content::Timeline

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
    def timeline(exclude_replies = false, inclusion = nil, page = 1, size = 10)
      exclude_replies =
        exclude_replies ?
        "AND likelihood(o.in_reply_to_iri IS NULL, 0.25)" :
        ""
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
          SELECT #{Timeline.columns(prefix: "t")}
            FROM relationships AS t
            JOIN objects AS o
              ON o.iri = t.to_iri
            JOIN actors AS c
              ON c.iri = o.attributed_to_iri
           WHERE +t.from_iri = ?
             #{inclusion}
             #{exclude_replies}
             #{common_filters_on("o", "c")}
        ORDER BY t.id DESC
           LIMIT ? OFFSET ?
      QUERY
      Timeline.query_and_paginate(query, self.iri, page: page, size: size)
    end

    # Returns the count of entries in the actor's timeline since the
    # given date.
    #
    # See `#timeline(inclusion, page, size)` for further details.
    #
    def timeline(since : Time, exclude_replies = false, inclusion = nil)
      exclude_replies =
        exclude_replies ?
        "AND likelihood(o.in_reply_to_iri IS NULL, 0.25)" :
        ""
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
             #{common_filters_on("o", "c")}
             AND t.created_at > ?
      QUERY
      Timeline.scalar(query, iri, since).as(Int64)
    end

    private alias Notification = Relationship::Content::Notification

    # Returns notifications for the actor.
    #
    # Meant to be called on local (not cached) actors.
    #
    def notifications(page = 1, size = 10)
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
            #{common_filters_on("c", "o", "a")}
            #{common_filters_on("e", "t")}
       ORDER BY n.id DESC
          LIMIT ? OFFSET ?
      QUERY
      Notification.query_and_paginate(query, iri, page: page, size: size)
    end

    # Returns the count of notifications for the actor since the given
    # date.
    #
    # See `#notifications(page, size)` for further details.
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
            #{common_filters_on("c", "o", "a")}
            #{common_filters_on("e", "t")}
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
    def terms(page = 1, size = 10)
      query = <<-QUERY
         SELECT #{FilterTerm.columns(prefix: "f")}
           FROM filter_terms AS f
          WHERE f.actor_id = ?
       ORDER BY f.id ASC
          LIMIT ? OFFSET ?
      QUERY
      FilterTerm.query_and_paginate(query, id, page: page, size: size)
    end

    def make_delete_activity
      ActivityPub::Activity::Delete.new(
        iri: "#{Ktistec.host}/activities/#{Ktistec::Util.id}",
        actor: self,
        object: self,
        to: ["https://www.w3.org/ns/activitystreams#Public"],
        cc: [followers, following].compact
      )
    end

    def to_json_ld(recursive = true)
      ActorModelHelper.to_json_ld(self, recursive)
    end

    def from_json_ld(json, *, include_key = false)
      self.assign(ActorModelHelper.from_json_ld(json, include_key))
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
      "iri" => json.dig?("@id").try(&.as_s),
      "_type" => json.dig?("@type").try(&.as_s.split("#").last),
      "username" => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#preferredUsername"),
      "pem_public_key" => if include_key
        Ktistec::JSON_LD.dig?(json, "https://w3id.org/security#publicKey", "https://w3id.org/security#publicKeyPem")
      end,
      "inbox" => Ktistec::JSON_LD.dig_id?(json, "http://www.w3.org/ns/ldp#inbox"),
      "outbox" => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#outbox"),
      "following" => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#following"),
      "followers" => Ktistec::JSON_LD.dig_id?(json, "https://www.w3.org/ns/activitystreams#followers"),
      "name" => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#name", "und"),
      "summary" => Ktistec::JSON_LD.dig?(json, "https://www.w3.org/ns/activitystreams#summary", "und"),
      "icon" => map_icon?(json, "https://www.w3.org/ns/activitystreams#icon"),
      "image" => map_icon?(json, "https://www.w3.org/ns/activitystreams#image"),
      "urls" => Ktistec::JSON_LD.dig_ids?(json, "https://www.w3.org/ns/activitystreams#url"),
      "attachments" => Ktistec::JSON_LD.dig_values?(json, "https://www.w3.org/ns/activitystreams#attachment") do |attachment|
        name = Ktistec::JSON_LD.dig?(attachment, "https://www.w3.org/ns/activitystreams#name", "und").presence
        type = Ktistec::JSON_LD.dig?(attachment, "@type").presence
        value = Ktistec::JSON_LD.dig?(attachment, "http://schema.org#value").presence
        ActivityPub::Actor::Attachment.new(name, type, value) if name && type && value
      end
    }.compact
  end

  def self.map_icon?(json, *selector)
    json.dig?(*selector).try do |icons|
      if icons.as_a?
        icon =
          icons.as_a.map do |icon|
          if (width = icon.dig?("https://www.w3.org/ns/activitystreams#width")) && (height = icon.dig?("https://www.w3.org/ns/activitystreams#height"))
            {width.as_i * height.as_i, icon}
          else
            {0, icon}
          end
        end.sort do |(a, _), (b, _)|
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
