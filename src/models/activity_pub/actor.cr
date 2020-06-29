require "../../framework/model"
require "json"

module ActivityPub
  class Actor
    include Balloon::Model(Common, Polymorphic, Serialized)

    @@table_name = "actors"

    def self.find(_iri iri : String?)
      find(iri: iri)
    end

    def self.find?(_iri iri : String?)
      find?(iri: iri)
    end

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

    def follow(other : Actor, **options)
      Relationship::Social::Follow.new(**options.merge({from_iri: self.iri, to_iri: other.iri}))
    end

    def follows?(other : Actor)
      Relationship::Social::Follow.find?(from_iri: self.iri, to_iri: other.iri)
    end

    private def query(type, orig, dest, public = false)
      {% begin %}
        {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
        if public
          query = <<-QUERY
            SELECT {{ vs.map{ |v| "a.#{v}" }.join(",").id }}
              FROM actors AS a, relationships AS r
             WHERE a.iri = r.#{orig}
               AND r.type = "#{type}"
               AND r.confirmed = 1 AND r.visible = 1
               AND r.#{dest} = ?
               AND a.id NOT IN (
                  SELECT a.id
                    FROM actors AS a, relationships AS r
                   WHERE a.iri = r.#{orig}
                     AND r.type = "#{type}"
                     AND r.confirmed = 1 AND r.visible = 1
                     AND r.#{dest} = ?
                ORDER BY r.created_at DESC
                   LIMIT ?
               )
          ORDER BY r.created_at DESC
             LIMIT ?
          QUERY
        else
          query = <<-QUERY
            SELECT {{ vs.map{ |v| "a.#{v}" }.join(",").id }}
              FROM actors AS a, relationships AS r
             WHERE a.iri = r.#{orig}
               AND r.type = "#{type}"
               AND r.#{dest} = ?
               AND a.id NOT IN (
                  SELECT a.id
                    FROM actors AS a, relationships AS r
                   WHERE a.iri = r.#{orig}
                     AND r.type = "#{type}"
                     AND r.#{dest} = ?
                ORDER BY r.created_at DESC
                   LIMIT ?
               )
          ORDER BY r.created_at DESC
             LIMIT ?
          QUERY
        end
      {% end %}
    end

    def all_following(page : UInt16 = 0, size : UInt16 = 10, public = false)
      {% begin %}
        {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
        Balloon::Util::PaginatedArray(Actor).new.tap do |array|
          Balloon.database.query(
            query(Relationship::Social::Follow, :to_iri, :from_iri, public),
            self.iri, self.iri, (page * size).to_i, size.to_i + 1
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

    def all_followers(page : UInt16 = 0, size : UInt16 = 10, public = false)
      {% begin %}
        {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
        Balloon::Util::PaginatedArray(Actor).new.tap do |array|
          Balloon.database.query(
            query(Relationship::Social::Follow, :from_iri, :to_iri, public),
            self.iri, self.iri, (page * size).to_i, size.to_i + 1
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

    def self.from_json_ld(json)
      self.new(**map(json))
    end

    def from_json_ld(json)
      self.assign(**self.class.map(json))
    end

    def self.map(json)
      json = Balloon::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String)
      {
        iri: json.dig?("@id").try(&.as_s),
        username: dig?(json, "https://www.w3.org/ns/activitystreams#preferredUsername"),
        pem_public_key: dig?(json, "https://w3id.org/security#publicKey", "https://w3id.org/security#publicKeyPem"),
        pem_private_key: dig?(json, "https://w3id.org/security#privateKey", "https://w3id.org/security#privateKeyPem"),
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
