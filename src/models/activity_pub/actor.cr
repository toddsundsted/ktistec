require "../../framework/model"
require "json"

module ActivityPub
  class Actor
    include Balloon::Model(Common, Polymorphic)

    @@table_name = "actors"

    def initialize(**options)
      keypair = OpenSSL::RSA.generate(2048, 17)
      assign(**{
        pem_public_key: keypair.public_key.to_pem,
        pem_private_key: keypair.to_pem
      }.merge(options))
    end

    @[Persistent]
    property aid : String?

    def local?
      aid.nil?
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
    property name : String?

    @[Persistent]
    property summary : String?

    @[Persistent]
    property icon : String?

    @[Persistent]
    property image : String?

    def self.from_json_ld(json)
      json = Balloon::JSON_LD.expand(JSON.parse(json))
      self.new(
        aid: json.dig?("@id").try(&.as_s),
        type: json.dig?("@type").try(&.as_s),
        username: json.dig?("https://www.w3.org/ns/activitystreams#preferredUsername").try(&.as_s),
        pem_public_key: json.dig?("https://w3id.org/security#publicKey", "https://w3id.org/security#publicKeyPem").try(&.as_s),
        pem_private_key: json.dig?("https://w3id.org/security#privateKey", "https://w3id.org/security#privateKeyPem").try(&.as_s),
        name: json.dig?("https://www.w3.org/ns/activitystreams#name").try(&.as_s),
        summary: json.dig?("https://www.w3.org/ns/activitystreams#summary").try(&.as_s),
        icon: json.dig?("https://www.w3.org/ns/activitystreams#icon", "https://www.w3.org/ns/activitystreams#url").try(&.as_s),
        image: json.dig?("https://www.w3.org/ns/activitystreams#image", "https://www.w3.org/ns/activitystreams#url").try(&.as_s)
      )
    end
  end
end
