require "crypto/bcrypt/password"
require "openssl_ext"

require "../framework/model"
require "../framework/model/**"
require "./activity_pub/actor"
require "./session"

private def check_timezone?(timezone)
  Time::Location.load(timezone)
rescue Time::Location::InvalidLocationNameError
end

# An ActivityPub account.
#
# Also an account.
#
class Account
  include Ktistec::Model(Common)

  # :nodoc:
  private def cost
    12
  end

  # Allocates a new account.
  #
  # This constructor is used to create new accounts (which must have a
  # valid username and password).
  #
  def self.new(user username : String, pass password : String, **options)
    new(**options.merge({
      username: username,
      password: password
    }))
  end

  @[Persistent]
  property username : String

  @[Persistent]
  getter encrypted_password : String

  @[Assignable]
  @password : String?

  # Validates the given password.
  #
  def valid_password?(password)
    Crypto::Bcrypt::Password.new(encrypted_password).verify(password)
  end

  def password=(password)
    if (password = password.presence)
      @encrypted_password = Crypto::Bcrypt::Password.create(password, self.cost).to_s
      @password = password
    end
  end

  def password
    @password
  end

  def before_save
    if changed?(:actor)
      clear!(:actor)
      if (actor = self.actor?) && actor.pem_public_key.nil? && actor.pem_private_key.nil?
        keypair = OpenSSL::RSA.generate(2048, 17)
        actor.pem_public_key = keypair.public_key.to_pem
        actor.pem_private_key = keypair.to_pem
      end
    end
  end

  def before_validate
    if changed?(:username)
      clear!(:username)
      if (username = self.username)
        host = Ktistec.host
        self.iri = "#{host}/actors/#{username}"
      end
    end
  end

  def validate_model
    if (username = @username)
      messages = [] of String
      messages << "is too short" unless username.size >= 1
      messages << "contains invalid characters" unless username.each_char.all? { |char| char.ascii_alphanumeric? || char.in?('_', '.', '-', '~') }
      messages << "must be unique" unless (accounts = Account.where(username: username)).empty? || accounts.all? { |account| account.id == self.id }
      errors["username"] = messages unless messages.empty?
    end
    if (password = @password)
      messages = [] of String
      messages << "is too short" unless password.size >= 6
      messages << "is weak" unless password =~ /[^a-zA-Z0-9]/ && password =~ /[a-zA-Z]/ && password =~ /[0-9]/
      errors["password"] = messages unless messages.empty?
    end
  end

  @[Persistent]
  property timezone : String { "" }
  validates(timezone) { "is unsupported" unless check_timezone?(timezone) }

  @[Persistent]
  property iri : String { "" }

  belongs_to actor, class_name: ActivityPub::Actor, foreign_key: iri, primary_key: iri

  has_many sessions

  # permits an account to be used in path helpers in place of
  # an actor.
  def uid
    username
  end

  struct State
    include JSON::Serializable

    property last_timeline_checked_at : Time { Time::UNIX_EPOCH }
    property last_notifications_checked_at : Time { Time::UNIX_EPOCH }
  end

  @[Persistent]
  property state : State

  delegate last_timeline_checked_at, last_notifications_checked_at, to: @state

  def update_last_timeline_checked_at(time = Time.utc)
    state.last_timeline_checked_at = time
    self
  end

  def update_last_notifications_checked_at(time = Time.utc)
    state.last_notifications_checked_at = time
    self
  end
end
