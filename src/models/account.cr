require "crypto/bcrypt/password"
require "openssl_ext"

require "../framework/model"
require "../framework/model/**"
require "./activity_pub/actor"
require "./last_time"
require "./session"

private def check_language?(language)
  language.nil? || language =~ Ktistec::Constants::LANGUAGE_RE
end

private def check_timezone?(timezone)
  Time::Location.load(timezone)
rescue Time::Location::InvalidLocationNameError
end

# An ActivityPub account.
#
# Also an account.
#
class Account
  include Ktistec::Model
  include Ktistec::Model::Common

  @[Persistent]
  property username : String

  @[Persistent]
  getter encrypted_password : String

  @[Assignable]
  @password : String?

  # Password encryption and key generation should be expensive
  # operations in normal use cases. Parameterize `cost` and `size` so
  # that they can be redefined in test, where the expense just makes
  # the tests run more slowly.

  # :nodoc:
  private def cost
    12
  end

  # :nodoc:
  private def size
    2048
  end

  # Checks the given password against the encrypted password.
  #
  def check_password(password)
    Crypto::Bcrypt::Password.new(encrypted_password).verify(password)
  end

  # handle two use cases common in bulk assignment: 1) account
  # creation, in which it should accept *and validate* any value
  # including a blank string (the user just hits submit on the form),
  # 2) account update, in which it should *ignore* a blank value (the
  # user left the field empty and did not intend to change the
  # password).

  def password=(password)
    if (password && new_record?) || (password = password.presence)
      @encrypted_password = Crypto::Bcrypt::Password.create(password, self.cost).to_s
      changed!(:encrypted_password)
      @password = password
    end
  end

  def password
    @password
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

  def before_save
    if changed?(:actor)
      clear!(:actor)
      if (actor = self.actor?) && actor.pem_public_key.nil? && actor.pem_private_key.nil?
        keypair = OpenSSL::RSA.generate(self.size, 17)
        actor.pem_public_key = keypair.public_key.to_pem
        actor.pem_private_key = keypair.to_pem
      end
    end
  end

  def after_save
    @password = nil
  end

  @[Persistent]
  property language : String?
  validates(language) do
    return "cannot be blank" unless language.presence
    return "is unsupported" unless check_language?(language)
  end

  @[Persistent]
  property timezone : String { "" }
  validates(timezone) { "is unsupported" unless check_timezone?(timezone) }

  @[Persistent]
  property iri : String { "" }

  belongs_to actor, class_name: ActivityPub::Actor, foreign_key: iri, primary_key: iri

  has_many sessions

  has_many last_times

  # permits an account to be used in path helpers in place of
  # an actor.
  def uid
    username
  end

  private LAST_TIMELINE_CHECKED_AT = "last_timeline_checked_at"
  private LAST_NOTIFICATIONS_CHECKED_AT = "last_notifications_checked_at"

  def last_timeline_checked_at
    LastTime.find?(account: self, name: LAST_TIMELINE_CHECKED_AT).try(&.timestamp) ||
      Time::UNIX_EPOCH
  end

  def last_notifications_checked_at
    LastTime.find?(account: self, name: LAST_NOTIFICATIONS_CHECKED_AT).try(&.timestamp) ||
      Time::UNIX_EPOCH
  end

  def update_last_timeline_checked_at(time = Time.utc)
    last_time = LastTime.find?(account: self, name: LAST_TIMELINE_CHECKED_AT) ||
      LastTime.new(account: self, name: LAST_TIMELINE_CHECKED_AT)
    last_time.assign(timestamp: time).save
    self
  end

  def update_last_notifications_checked_at(time = Time.utc)
    last_time = LastTime.find?(account: self, name: LAST_NOTIFICATIONS_CHECKED_AT) ||
      LastTime.new(account: self, name: LAST_NOTIFICATIONS_CHECKED_AT)
    last_time.assign(timestamp: time).save
    self
  end
end
