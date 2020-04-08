require "../framework/model"
require "crypto/bcrypt/password"
require "openssl_ext"

# An ActivityPub actor.
#
# Also an account.
#
class Actor
  include Balloon::Model

  # :nodoc:
  private def self.cost
    12
  end

  # Allocates a new actor.
  #
  # This constructor is used to create new actors (which must have a
  # valid username and password).
  #
  def self.new(username, password, **options)
    keypair = OpenSSL::RSA.generate(2048, 17)
    new(**options.merge({
      username: username,
      encrypted_password: Crypto::Bcrypt::Password.create(password, cost).to_s,
      pem_public_key: keypair.public_key.to_pem,
      pem_private_key: keypair.to_pem
    }))
  end

  # Sets the password.
  #
  def password=(password)
    self.encrypted_password = Crypto::Bcrypt::Password.create(password).to_s
  end

  # Validates the given password.
  #
  def valid_password?(password)
    Crypto::Bcrypt::Password.new(encrypted_password).verify(password)
  end

  @[Persistent]
  property username : String

  @[Persistent]
  property encrypted_password : String

  @[Persistent]
  property pem_public_key : String

  @[Persistent]
  property pem_private_key : String

  def public_key
    OpenSSL::RSA.new(pem_public_key, nil, false)
  end

  def private_key
    OpenSSL::RSA.new(pem_private_key, nil, true)
  end

  def sessions
    Session.where(actor_id: self.id)
  end
end
