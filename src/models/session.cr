require "../framework/model"
require "json"

# Client session.
#
class Session
  include Ktistec::Model(Common)

  # Allocates a new session for an account.
  #
  def self.new(_account account)
    new(account_id: account.id)
  end

  @[Persistent]
  property session_key : String { Random::Secure.urlsafe_base64 }

  @[Persistent]
  property body_json : String { "{}" }

  @[Persistent]
  property account_id : Int64?

  def body
    JSON.parse(body_json)
  end

  def body=(body)
    self.body_json = body.to_json
    body
  end

  belongs_to account
end
