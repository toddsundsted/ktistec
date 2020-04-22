require "../framework/model"
require "crypto/bcrypt/password"
require "openssl_ext"

# An ActivityPub actor.
#
# Also an account.
#
class Actor
  include Balloon::Model(Common)

  # :nodoc:
  private def cost
    12
  end

  # Allocates a new actor.
  #
  # This constructor is used to create new actors (which must have a
  # valid username and password).
  #
  def self.new(username, password)
    keypair = OpenSSL::RSA.generate(2048, 17)
    new(
      username: username,
      password: password,
      pem_public_key: keypair.public_key.to_pem,
      pem_private_key: keypair.to_pem
    )
  end

  @[Persistent]
  property username : String

  @[Persistent]
  property encrypted_password : String

  @[Assignable]
  @password : String?

  # Validates the given password.
  #
  def valid_password?(password)
    Crypto::Bcrypt::Password.new(encrypted_password).verify(password)
  end

  def password=(@password)
    self.encrypted_password = Crypto::Bcrypt::Password.create(password, self.cost).to_s
  end

  def password
    @password
  end

  def validate
    super
    if username = self.username
      messages = [] of String
      messages << "is too short" unless username.size >= 1
      messages << "must be unique" unless (actors = Actor.where(username: username)).empty? || actors.all? { |actor| actor.id == self.id }
      errors["username"] = messages unless messages.empty?
    end
    if password = self.password
      messages = [] of String
      messages << "is weak" unless password =~ /[^a-zA-Z0-9]/ && password =~ /[a-zA-Z]/ && password =~ /[0-9]/
      messages << "is too short" unless password.size >= 6
      errors["password"] = messages unless messages.empty?
    end
    errors
  end

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

  has_many sessions
end
