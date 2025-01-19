require "openssl_ext"

require "../../src/framework/key_pair"

class KeyPair
  include Ktistec::KeyPair

  def initialize(@iri : String)
    keypair = OpenSSL::RSA.generate(512, 17)
    @public_key = keypair.public_key
    @private_key = keypair
  end

  property iri : String
  property public_key : OpenSSL::RSA
  property private_key : OpenSSL::RSA
end
