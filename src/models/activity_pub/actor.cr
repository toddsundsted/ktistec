require "../../framework/model"
require "json"

module ActivityPub
  class Actor
    include Balloon::Model(Common, Polymorphic)

    @@table_name = "actors"

    @[Persistent]
    property aid : String?
    validates(aid) { unique_absolute_uri?(aid) }

    private def unique_absolute_uri?(aid)
      if aid.nil?
        "must be present"
      elsif !URI.parse(aid).absolute?
        "must be an absolute URI"
      elsif (actor = Actor.find?(aid: aid)) && actor.id != self.id
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

    def self.from_json_ld(json)
      self.new(**map(json))
    end

    def from_json_ld(json)
      self.assign(**map(json))
    end
  end
end

private def map(json)
  json = Balloon::JSON_LD.expand(JSON.parse(json)) if json.is_a?(String)
  {
    aid: json.dig?("@id").try(&.as_s),
    type: json.dig?("@type").try(&.as_s),
    username: json.dig?("https://www.w3.org/ns/activitystreams#preferredUsername").try(&.as_s),
    pem_public_key: json.dig?("https://w3id.org/security#publicKey", "https://w3id.org/security#publicKeyPem").try(&.as_s),
    pem_private_key: json.dig?("https://w3id.org/security#privateKey", "https://w3id.org/security#privateKeyPem").try(&.as_s),
    inbox: json.dig?("http://www.w3.org/ns/ldp#inbox").try(&.as_s),
    outbox: json.dig?("https://www.w3.org/ns/activitystreams#outbox").try(&.as_s),
    following: json.dig?("https://www.w3.org/ns/activitystreams#following").try(&.as_s),
    followers: json.dig?("https://www.w3.org/ns/activitystreams#followers").try(&.as_s),
    name: json.dig?("https://www.w3.org/ns/activitystreams#name").try(&.as_s),
    summary: json.dig?("https://www.w3.org/ns/activitystreams#summary").try(&.as_s),
    icon: json.dig?("https://www.w3.org/ns/activitystreams#icon", "https://www.w3.org/ns/activitystreams#url").try(&.as_s),
    image: json.dig?("https://www.w3.org/ns/activitystreams#image", "https://www.w3.org/ns/activitystreams#url").try(&.as_s)
  }
end
