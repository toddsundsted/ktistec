require "json"

require "../framework/jwt"
require "../framework/model"
require "../framework/model/**"
require "./account"

# Client session.
#
class Session
  include Ktistec::Model(Common)

  # Allocates a new session for an account.
  #
  def self.new(_account account : Account)
    new(account: account)
  end

  @[Persistent]
  property session_key : String { Random::Secure.urlsafe_base64 }

  @[Persistent]
  property body_json : String { "{}" }

  @[Persistent]
  property account_id : Int64?
  belongs_to account

  def body
    JSON.parse(body_json)
  end

  def body=(body)
    self.body_json = body.to_json
    body
  end

  def string(key, value)
    self.body = self.body.as_h.merge({key => value})
    save
  end

  def string(key)
    self.body[key].as_s
  end

  def string?(key)
    self.body[key]?.try(&.as_s)
  end

  @jwt : String?

  def generate_jwt
    @jwt ||= begin
      payload = {"jti" => session_key, "iat" => Time.utc}
      Ktistec::JWT.encode(payload)
    end
  end

  def self.find_by_jwt?(jwt)
    if (payload = Ktistec::JWT.decode(jwt))
      unless Ktistec::JWT.expired?(payload)
        Session.find(session_key: payload["jti"].as_s)
      end
    end
  rescue Ktistec::JWT::Error | Ktistec::Model::NotFound
  end

  def self.clean_up_stale_sessions(time = 1.day.ago)
    delete = "DELETE FROM sessions WHERE account_id IS NULL AND updated_at < ?"
    exec(delete, time)
  end
end
