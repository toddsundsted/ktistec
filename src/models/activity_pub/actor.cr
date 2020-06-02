require "../../framework/model"
require "json"

module ActivityPub
  class Actor
    include Balloon::Model(Common, Polymorphic)

    @@table_name = "actors"

    def self.find(_iri iri : String?)
      find(iri: iri)
    end

    def self.find?(_iri iri : String?)
      find?(iri: iri)
    end

    @[Persistent]
    property iri : String?
    validates(iri) { unique_absolute_uri?(iri) }

    private def unique_absolute_uri?(iri)
      if iri.nil?
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
    property url : String?

    def self.from_json_ld(json)
      self.new(**map(json))
    end

    def from_json_ld(json)
      self.assign(**map(json))
    end

    def follow(other : Actor)
      Relationship::Social::Follow.new(from_iri: self.iri, to_iri: other.iri)
    end

    def follows?(other : Actor)
      Relationship::Social::Follow.find?(from_iri: self.iri, to_iri: other.iri)
    end

    def all_following(page : UInt16 = 0, size : UInt16 = 10)
      {% begin %}
        {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
        query = <<-QUERY
          SELECT {{ vs.map{ |v| "a.#{v}" }.join(",").id }}
            FROM actors AS a, relationships AS r
           WHERE a.iri = r.to_iri
             AND r.type = "#{Relationship::Social::Follow}"
             AND r.from_iri = ?
             AND a.id NOT IN (
                SELECT a.id
                  FROM actors AS a, relationships AS r
                 WHERE a.iri = r.to_iri
                   AND r.type = "#{Relationship::Social::Follow}"
                   AND r.from_iri = ?
              ORDER BY r.created_at DESC
                 LIMIT ?
             )
        ORDER BY r.created_at DESC
           LIMIT ?
        QUERY
        Balloon.database.query_all(
          query, self.iri, self.iri, (page * size).to_i, size.to_i
        ) do |rs|
          Actor.new(
            {% for v in vs %}
              {{v}}: rs.read({{v.type}}),
            {% end %}
          )
        end
      {% end %}
    end

    def all_followers(page : UInt16 = 0, size : UInt16 = 10)
      {% begin %}
        {% vs = @type.instance_vars.select(&.annotation(Persistent)) %}
        query = <<-QUERY
          SELECT {{ vs.map{ |v| "a.#{v}" }.join(",").id }}
            FROM actors AS a, relationships AS r
           WHERE a.iri = r.from_iri
             AND r.type = "#{Relationship::Social::Follow}"
             AND r.to_iri = ?
             AND a.id NOT IN (
                SELECT a.id
                  FROM actors AS a, relationships AS r
                 WHERE a.iri = r.from_iri
                   AND r.type = "#{Relationship::Social::Follow}"
                   AND r.to_iri = ?
              ORDER BY r.created_at DESC
                 LIMIT ?
             )
        ORDER BY r.created_at DESC
           LIMIT ?
        QUERY
        Balloon.database.query_all(
          query, self.iri, self.iri, (page * size).to_i, size.to_i
        ) do |rs|
          Actor.new(
            {% for v in vs %}
              {{v}}: rs.read({{v.type}}),
            {% end %}
          )
        end
      {% end %}
    end
  end
end

private def map(json)
  json = Balloon::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String)
  {
    iri: json.dig?("@id").try(&.as_s),
    username: json.dig?("https://www.w3.org/ns/activitystreams#preferredUsername").try(&.as_s),
    pem_public_key: json.dig?("https://w3id.org/security#publicKey", "https://w3id.org/security#publicKeyPem").try(&.as_s),
    pem_private_key: json.dig?("https://w3id.org/security#privateKey", "https://w3id.org/security#privateKeyPem").try(&.as_s),
    inbox: json.dig?("http://www.w3.org/ns/ldp#inbox").try(&.as_s),
    outbox: json.dig?("https://www.w3.org/ns/activitystreams#outbox").try(&.as_s),
    following: json.dig?("https://www.w3.org/ns/activitystreams#following").try(&.as_s),
    followers: json.dig?("https://www.w3.org/ns/activitystreams#followers").try(&.as_s),
    name: json.dig?("https://www.w3.org/ns/activitystreams#name").try(&.as_h.dig?("und")).try(&.as_s),
    summary: json.dig?("https://www.w3.org/ns/activitystreams#summary").try(&.as_h.dig?("und")).try(&.as_s),
    icon: json.dig?("https://www.w3.org/ns/activitystreams#icon", "https://www.w3.org/ns/activitystreams#url").try(&.as_s),
    image: json.dig?("https://www.w3.org/ns/activitystreams#image", "https://www.w3.org/ns/activitystreams#url").try(&.as_s),
    url: json.dig?("https://www.w3.org/ns/activitystreams#url").try(&.as_s)
  }
end
