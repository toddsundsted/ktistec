require "../../framework/model"
require "json"

module ActivityPub
  class Actor
    include Ktistec::Model(Common, Deletable, Polymorphic, Serialized, Linked)

    @@table_name = "actors"

    @[Persistent]
    property iri : String { "" }
    validates(iri) { unique_absolute_uri?(iri) }

    private def unique_absolute_uri?(iri)
      if iri.blank?
        "must be present"
      elsif !URI.parse(iri).absolute?
        "must be an absolute URI"
      elsif (actor = Actor.find?(iri)) && actor.id != self.id
        "must be unique"
      end
    end

    def local
      iri.starts_with?(Ktistec.host)
    end

    @[Persistent]
    property username : String?

    @[Persistent]
    property pem_public_key : String?

    @[Persistent]
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

    def display_name
      name.presence || username.presence || iri
    end

    def display_link
      urls.try(&.first?) || iri
    end

    def account_uri
      %Q|#{username}@#{URI.parse(iri).host}|
    end

    def follow(other : Actor, **options)
      Relationship::Social::Follow.new(**options.merge({from_iri: self.iri, to_iri: other.iri}))
    end

    def follows?(other : Actor)
      Relationship::Social::Follow.find?(from_iri: self.iri, to_iri: other.iri)
    end

    private def query(type, orig, dest, public = false)
      {% begin %}
        {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
        query = <<-QUERY
          SELECT {{ vs.map{ |v| "a.#{v}" }.join(",").id }}
            FROM actors AS a, relationships AS r
           WHERE a.iri = r.#{orig}
             AND r.type = "#{type}"
        #{public ? "AND r.confirmed = 1 AND r.visible = 1" : nil}
             AND r.#{dest} = ?
             AND a.id NOT IN (
                SELECT a.id
                  FROM actors AS a, relationships AS r
                 WHERE a.iri = r.#{orig}
                   AND r.type = "#{type}"
              #{public ? "AND r.confirmed = 1 AND r.visible = 1" : nil}
                   AND r.#{dest} = ?
              ORDER BY r.created_at DESC
                 LIMIT ?
             )
        ORDER BY r.created_at DESC
           LIMIT ?
        QUERY
      {% end %}
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

    private def query_and_paginate(query, page = 1, size = 10)
      {% begin %}
        {% vs = ActivityPub::Activity.instance_vars.select(&.annotation(Persistent)) %}
        Ktistec::Util::PaginatedArray(Activity).new.tap do |array|
          Ktistec.database.query(
            query, self.iri, self.iri, ((page - 1) * size).to_i, size.to_i + 1
          ) do |rs|
            rs.each do
              attrs = {
               {% for v in vs %}
                 {{v}}: rs.read({{v.type}}),
               {% end %}
              }
              array <<
                case attrs[:type]
                {% for subclass in ActivityPub::Activity.all_subclasses %}
                  when {{name = subclass.stringify}}
                    {{subclass}}.new(**attrs)
                {% end %}
                else
                  ActivityPub::Activity.new(**attrs)
                end
            end
          end
          if array.size > size
            array.more = true
            array.pop
          end
        end
      {% end %}
    end

    private def content(type, page = 1, size = 10, public = true)
      {% begin %}
        {% vs = ActivityPub::Activity.instance_vars.select(&.annotation(Persistent)) %}
        query = <<-QUERY
           SELECT {{ vs.map{ |v| "a.\"#{v}\"" }.join(",").id }}
             FROM activities AS a, relationships AS r
        LEFT JOIN objects AS o
               ON o.iri = a.object_iri
            WHERE r.from_iri = ?
              AND r.type = "#{type}"
              AND r.confirmed = 1
              AND o.deleted_at is NULL
              AND a.iri = r.to_iri
         #{public ? %Q|AND a.visible = 1| : nil}
              AND a.id NOT IN (
                 SELECT a.id
                   FROM activities AS a, relationships AS r
              LEFT JOIN objects AS o
                     ON o.iri = a.object_iri
                  WHERE r.from_iri = ?
                    AND r.type = "#{type}"
                    AND r.confirmed = 1
                    AND o.deleted_at is NULL
                    AND a.iri = r.to_iri
               #{public ? %Q|AND a.visible = 1| : nil}
               ORDER BY r.created_at DESC
                  LIMIT ?
              )
         ORDER BY r.created_at DESC
            LIMIT ?
        QUERY
        query_and_paginate(query, page, size)
      {% end %}
    end

    def in_outbox(page = 1, size = 10, public = true)
      content(Relationship::Content::Outbox, page, size, public)
    end

    def in_inbox(page = 1, size = 10, public = true)
      content(Relationship::Content::Inbox, page, size, public)
    end

    def both_mailboxes(page = 1, size = 10)
      {% begin %}
        {% vs = ActivityPub::Activity.instance_vars.select(&.annotation(Persistent)) %}
        query = <<-QUERY
           SELECT {{ vs.map{ |v| "a.\"#{v}\"" }.join(",").id }}
             FROM activities AS a, relationships AS r
        LEFT JOIN objects AS o
               ON o.iri = a.object_iri
            WHERE r.from_iri = ?
              AND r.type IN ("#{Relationship::Content::Inbox}", "#{Relationship::Content::Outbox}")
              AND r.confirmed = 1
              AND o.deleted_at is NULL
              AND a.iri = r.to_iri
              AND a.type IN ("#{ActivityPub::Activity::Create}", "#{ActivityPub::Activity::Announce}")
              AND a.id NOT IN (
                 SELECT a.id
                   FROM activities AS a, relationships AS r
              LEFT JOIN objects AS o
                     ON o.iri = a.object_iri
                  WHERE r.from_iri = ?
                    AND r.type IN ("#{Relationship::Content::Inbox}", "#{Relationship::Content::Outbox}")
                    AND r.confirmed = 1
                    AND o.deleted_at is NULL
                    AND a.iri = r.to_iri
                    AND a.type IN ("#{ActivityPub::Activity::Create}", "#{ActivityPub::Activity::Announce}")
               ORDER BY r.created_at DESC
                  LIMIT ?
              )
         ORDER BY r.created_at DESC
            LIMIT ?
        QUERY
        query_and_paginate(query, page, size)
      {% end %}
    end

    def public_posts(page = 1, size = 10)
      {% begin %}
        {% vs = ActivityPub::Activity.instance_vars.select(&.annotation(Persistent)) %}
        query = <<-QUERY
           SELECT {{ vs.map{ |v| "a.\"#{v}\"" }.join(",").id }}
             FROM activities AS a
        LEFT JOIN objects AS o
               ON o.iri = a.object_iri
            WHERE o.attributed_to_iri = ?
              AND o.deleted_at is NULL
              AND a.type IN ("#{ActivityPub::Activity::Create}", "#{ActivityPub::Activity::Announce}")
              AND a.visible = 1
              AND a.id NOT IN (
                 SELECT a.id
                   FROM activities AS a
              LEFT JOIN objects AS o
                     ON o.iri = a.object_iri
                  WHERE o.attributed_to_iri = ?
                    AND o.deleted_at is NULL
                    AND a.type IN ("#{ActivityPub::Activity::Create}", "#{ActivityPub::Activity::Announce}")
                    AND a.visible = 1
               ORDER BY o.published DESC
                  LIMIT ?
              )
         ORDER BY o.published DESC
            LIMIT ?
        QUERY
        query_and_paginate(query, page, size)
      {% end %}
    end

    def to_json_ld(recursive = false)
      ActorsController.render_actor(self, recursive)
    end

    def self.from_json_ld(json, *, include_key = false)
      ActivityPub.from_json_ld(json, include_key: include_key, default: self).as(self)
    end

    def self.from_json_ld?(json, *, include_key = false)
      ActivityPub.from_json_ld?(json, include_key: include_key, default: self).as(self?)
    rescue TypeCastError
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
  end
end
