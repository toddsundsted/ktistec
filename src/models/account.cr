require "../framework/model"
require "crypto/bcrypt/password"
require "openssl_ext"

# An ActivityPub account.
#
# Also an account.
#
class Account
  include Balloon::Model(Common)

  # :nodoc:
  private def cost
    12
  end

  # Allocates a new account.
  #
  # This constructor is used to create new accounts (which must have a
  # valid username and password).
  #
  def self.new(user username, pass password, **options)
    new(**options.merge({
      username: username,
      password: password
    }))
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
      messages << "must be unique" unless (accounts = Account.where(username: username)).empty? || accounts.all? { |account| account.id == self.id }
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
  property aid : String { "#{Balloon.config.host}/actors/#{username}" }

  belongs_to actor, class_name: ActivityPub::Actor, foreign_key: aid, primary_key: aid

  has_many sessions
end
