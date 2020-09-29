require "../framework/model"
require "json"

# Client session.
#
class Session
  include Ktistec::Model(Common)

  # Allocates a new session.
  #
  # This constructor is used to create new sessions (which must belong
  # to an account).
  #
  def self.new(account, body = "", **options)
    new(**options.merge({
      session_key: Random::Secure.urlsafe_base64,
      body_json: body.to_json,
      account_id: account.id,
    }))
  end

  @[Persistent]
  property session_key : String

  @[Persistent]
  property body_json : String

  @[Persistent]
  property account_id : Int64

  def body
    JSON.parse(body_json)
  end

  def body=(body)
    self.body_json = body.to_json
    body
  end

  belongs_to account
end
