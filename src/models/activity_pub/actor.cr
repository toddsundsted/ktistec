require "json"
require "openssl_ext"

require "../../framework/util"
require "../../framework/json_ld"
require "../../framework/ext/sqlite3"
require "../../framework/model"
require "../../framework/model/**"
require "../activity_pub"
require "../relationship/content/inbox"
require "../relationship/content/outbox"
require "../relationship/social/follow"
require "./activity"
require "./activity/announce"
require "./activity/create"
require "./activity/delete"
require "./activity/like"
require "./activity/undo"
require "./object"

module ActivityPub
  class Actor
    include Ktistec::Model(Common, Deletable, Polymorphic, Serialized, Linked)
    include ActivityPub

    @@table_name = "actors"

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

    def before_validate
      if changed?(:username)
        if (username = self.username) && ((iri.blank? && new_record?) || local?)
          clear!(:username)
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

    def display_name
      name.presence || username.presence || iri
    end

    def display_link
      urls.try(&.first?) || iri
    end

    def account_uri
      %Q|#{username}@#{URI.parse(iri).host}|
    end

    def self.match?(account)
      if account =~ /^@?([^@]+)@([^@]+)$/
        where(username: $1).find do |actor|
          if (urls = actor.urls)
            urls.any? do |url|
              uri = URI.parse(url)
              uri.host.try(&.downcase) == $2.downcase && uri.path[2..].downcase == $1.downcase
            rescue URI::Error
            end
          end
        end
      end
    end

    def follow(other : Actor, **options)
      Relationship::Social::Follow.new(**options.merge({from_iri: self.iri, to_iri: other.iri}))
    end

    def follows?(other : Actor, **options)
      !other.deleted? ?
        Relationship::Social::Follow.find?(**options.merge({from_iri: self.iri, to_iri: other.iri})) :
        nil
    end

    private def query(type, orig, dest, public = true)
      public = public ? "AND r.confirmed = 1 AND r.visible = 1" : nil
      query = <<-QUERY
        SELECT #{Actor.columns(prefix: "a")}
          FROM actors AS a, relationships AS r
         WHERE a.deleted_at IS NULL
           AND a.iri = r.#{orig}
           AND r.type = "#{type}"
           AND r.#{dest} = ?
           #{public}
           AND a.id NOT IN (
              SELECT a.id
                FROM actors AS a, relationships AS r
               WHERE a.deleted_at IS NULL
                 AND a.iri = r.#{orig}
                 AND r.type = "#{type}"
                 AND r.#{dest} = ?
                 #{public}
            ORDER BY r.created_at DESC
               LIMIT ?
           )
      ORDER BY r.created_at DESC
         LIMIT ?
      QUERY
    end

    def all_following(page = 1, size = 10, public = true)
      {% begin %}
        {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
        Ktistec::Util::PaginatedArray(Actor).new.tap do |array|
          Ktistec.database.query(
            query(Relationship::Social::Follow, :to_iri, :from_iri, public),
            self.iri, self.iri, ((page - 1) * size).to_i, size.to_i + 1
          ) do |rs|
            rs.each do
              array <<
                Actor.new(
                 {% for v in vs %}
                   {{v}}: rs.read({{v.type}}),
                 {% end %}
                )
            end
          end
          if array.size > size
            array.more = true
            array.pop
          end
        end
      {% end %}
    end

    def all_followers(page = 1, size = 10, public = false)
      {% begin %}
        {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
        Ktistec::Util::PaginatedArray(Actor).new.tap do |array|
          Ktistec.database.query(
            query(Relationship::Social::Follow, :from_iri, :to_iri, public),
            self.iri, self.iri, ((page - 1) * size).to_i, size.to_i + 1
          ) do |rs|
            rs.each do
              array <<
                Actor.new(
                 {% for v in vs %}
                   {{v}}: rs.read({{v.type}}),
                 {% end %}
                )
            end
          end
          if array.size > size
            array.more = true
            array.pop
          end
        end
      {% end %}
    end

    def drafts(page = 1, size = 10)
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
          WHERE o.attributed_to_iri = ?
            AND o.published IS NULL
            AND o.deleted_at is NULL
            AND o.id NOT IN (
               SELECT o.id
                 FROM objects AS o
                WHERE o.attributed_to_iri = ?
                  AND o.published IS NULL
                  AND o.deleted_at is NULL
             ORDER BY o.created_at DESC
                LIMIT ?
            )
       ORDER BY o.created_at DESC
          LIMIT ?
      QUERY
      Object.query_and_paginate(query, iri, iri, page: page, size: size)
    end

    protected def self.content(iri, mailbox, inclusion = nil, exclusion = nil, page = 1, size = 10, public = true, replies = true)
      mailbox =
        case mailbox
        when Class
          %Q|AND r.type = "#{mailbox}"|
        when Array
          %Q|AND r.type IN (#{mailbox.map(&.to_s.inspect).join(",")})|
        end
      inclusion =
        case inclusion
        when Class
          %Q|AND a.type = "#{inclusion}"|
        when Array
          %Q|AND a.type IN (#{inclusion.map(&.to_s.inspect).join(",")})|
        end
      exclusion =
        case exclusion
        when Class
          %Q|AND a.type != "#{exclusion}"|
        when Array
          %Q|AND a.type NOT IN (#{exclusion.map(&.to_s.inspect).join(",")})|
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
      LEFT JOIN activities AS u
             ON u.object_iri = a.iri
            AND u.type = "#{ActivityPub::Activity::Undo}"
            AND u.actor_iri = a.actor_iri
          WHERE r.from_iri LIKE ?
            #{mailbox}
            AND r.confirmed = 1
            #{inclusion}
            #{exclusion}
            AND act.deleted_at is NULL
            AND obj.deleted_at is NULL
            AND u.iri IS NULL
       #{public ? %Q|AND a.visible = 1| : nil}
       #{!replies ? %Q|AND obj.in_reply_to_iri IS NULL| : nil}
            AND a.id NOT IN (
               SELECT a.id
                 FROM activities AS a
                 JOIN relationships AS r
                   ON r.to_iri = a.iri
            LEFT JOIN actors AS act
                   ON act.iri = a.actor_iri
            LEFT JOIN objects AS obj
                   ON obj.iri = a.object_iri
            LEFT JOIN activities AS u
                   ON u.object_iri = a.iri
                  AND u.type = "#{ActivityPub::Activity::Undo}"
                  AND u.actor_iri = a.actor_iri
                WHERE r.from_iri LIKE ?
                  #{mailbox}
                  AND r.confirmed = 1
                  #{inclusion}
                  #{exclusion}
                  AND act.deleted_at is NULL
                  AND obj.deleted_at is NULL
                  AND u.iri IS NULL
             #{public ? %Q|AND a.visible = 1| : nil}
             #{!replies ? %Q|AND obj.in_reply_to_iri IS NULL| : nil}
             ORDER BY r.created_at DESC
                LIMIT ?
            )
       ORDER BY r.created_at DESC
          LIMIT ?
      QUERY
      object_columns = Object.persistent_columns(prefix: :object)
      Activity.query_and_paginate(query, iri, iri, additional_columns: object_columns, page: page, size: size)
    end

    private def find_in?(object, mailbox, inclusion = nil, exclusion = nil)
      mailbox =
        case mailbox
        when Class
          %Q|AND r.type = "#{mailbox}"|
        when Array
          %Q|AND r.type IN (#{mailbox.map(&.to_s.inspect).join(",")})|
        end
      inclusion =
        case inclusion
        when Class
          %Q|AND a.type = "#{inclusion}"|
        when Array
          %Q|AND a.type IN (#{inclusion.map(&.to_s.inspect).join(",")})|
        end
      exclusion =
        case exclusion
        when Class
          %Q|AND a.type != "#{exclusion}"|
        when Array
          %Q|AND a.type NOT IN (#{exclusion.map(&.to_s.inspect).join(",")})|
        end
      query = <<-QUERY
         SELECT #{Activity.columns(prefix: "a")}
           FROM activities AS a
           JOIN relationships AS r
             ON r.to_iri = a.iri
           JOIN actors AS act
             ON act.iri = a.actor_iri
           JOIN objects AS obj
             ON obj.iri = a.object_iri
      LEFT JOIN activities AS u
             ON u.object_iri = a.iri AND u.type = "#{ActivityPub::Activity::Undo}" AND u.actor_iri = a.actor_iri
          WHERE r.from_iri = ?
            AND obj.iri = ?
            #{mailbox}
            AND r.confirmed = 1
            #{inclusion}
            #{exclusion}
            AND act.deleted_at is NULL
            AND obj.deleted_at is NULL
            AND u.iri IS NULL
      QUERY
      Activity.query_one(query, self.iri, object.iri)
    rescue DB::NoResultsError
    end

    def in_outbox(page = 1, size = 10, public = true)
      self.class.content(self.iri, Relationship::Content::Outbox, nil, [ActivityPub::Activity::Delete, ActivityPub::Activity::Undo], page, size, public)
    end

    def in_outbox?(object : Object, inclusion = nil, exclusion = nil)
      find_in?(object, Relationship::Content::Outbox, inclusion, exclusion)
    end

    def find_announce_in_outbox(object : Object)
      find_in?(object, Relationship::Content::Outbox, ActivityPub::Activity::Announce)
    end

    def find_like_in_outbox(object : Object)
      find_in?(object, Relationship::Content::Outbox, ActivityPub::Activity::Like)
    end

    def in_inbox(page = 1, size = 10, public = true)
      self.class.content(self. iri, Relationship::Content::Inbox, nil, [ActivityPub::Activity::Delete, ActivityPub::Activity::Undo], page, size, public)
    end

    def in_inbox?(object : Object, inclusion = nil, exclusion = nil)
      find_in?(object, Relationship::Content::Inbox, inclusion, exclusion)
    end

    def self.local_timeline(page = 1, size = 10)
      content(
        "#{Ktistec.host}%",
        Relationship::Content::Outbox,
        [ActivityPub::Activity::Create, ActivityPub::Activity::Announce],
        nil,
        page,
        size,
        true,
        false
      )
    end

    def both_mailboxes(page = 1, size = 10)
      self.class.content(
        self.iri,
        [Relationship::Content::Inbox, Relationship::Content::Outbox],
        [ActivityPub::Activity::Create, ActivityPub::Activity::Announce],
        nil,
        page,
        size,
        false,
        false
      )
    end

    def my_timeline(page = 1, size = 10)
      self.class.content(
        self.iri,
        Relationship::Content::Outbox,
        [ActivityPub::Activity::Create, ActivityPub::Activity::Announce],
        nil,
        page,
        size,
        true
      )
    end

    def public_posts(page = 1, size = 10)
      query = <<-QUERY
         SELECT #{Object.columns(prefix: "o")}
           FROM objects AS o
          WHERE o.attributed_to_iri = ?
            AND o.visible = 1
            AND o.deleted_at is NULL
            AND o.id NOT IN (
               SELECT o.id
                 FROM objects AS o
                WHERE o.attributed_to_iri = ?
                  AND o.visible = 1
                  AND o.deleted_at is NULL
             ORDER BY o.published DESC
                LIMIT ?
            )
       ORDER BY o.published DESC
          LIMIT ?
      QUERY
      Object.query_and_paginate(query, iri, iri, page: page, size: size)
    end

    def to_json_ld(recursive = false)
      actor = self
      render "src/views/actors/actor.json.ecr"
    end

    def from_json_ld(json, *, include_key = false)
      self.assign(**self.class.map(json, include_key: include_key))
    end

    def self.map(json, *, include_key = false, **option)
      json = Ktistec::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String | IO)
      {
        iri: json.dig?("@id").try(&.as_s),
        _type: json.dig?("@type").try(&.as_s.split("#").last),
        username: dig?(json, "https://www.w3.org/ns/activitystreams#preferredUsername"),
        pem_public_key: if include_key
          dig?(json, "https://w3id.org/security#publicKey", "https://w3id.org/security#publicKeyPem")
        end,
        inbox: dig_id?(json, "http://www.w3.org/ns/ldp#inbox"),
        outbox: dig_id?(json, "https://www.w3.org/ns/activitystreams#outbox"),
        following: dig_id?(json, "https://www.w3.org/ns/activitystreams#following"),
        followers: dig_id?(json, "https://www.w3.org/ns/activitystreams#followers"),
        name: dig?(json, "https://www.w3.org/ns/activitystreams#name", "und"),
        summary: dig?(json, "https://www.w3.org/ns/activitystreams#summary", "und"),
        icon: dig_id?(json, "https://www.w3.org/ns/activitystreams#icon", "https://www.w3.org/ns/activitystreams#url"),
        image: dig_id?(json, "https://www.w3.org/ns/activitystreams#image", "https://www.w3.org/ns/activitystreams#url"),
        urls: dig_ids?(json, "https://www.w3.org/ns/activitystreams#url")
      }
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
  end
end
