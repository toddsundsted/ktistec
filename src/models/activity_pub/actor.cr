require "../../framework/model"

module ActivityPub
  class Actor
    include Balloon::Model(Common, Polymorphic)

    @@table_name = "actors"

    def initialize(**options)
      keypair = OpenSSL::RSA.generate(2048, 17)
      assign(**options.merge({
        pem_public_key: keypair.public_key.to_pem,
        pem_private_key: keypair.to_pem
      }))
    end

    @[Persistent]
    property aid : String?

    def local?
      aid.nil?
    end

    @[Persistent]
    property username : String?

    belongs_to account, foreign_key: username, primary_key: username

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
  end
end
