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

  def string(key, value, *, expires_in = nil)
    self.body =
      if expires_in
        expiry = Time.utc.to_unix + expires_in.to_i
        self.body.as_h.merge({key => {"value" => value, "expiry" => expiry}})
      else
        self.body.as_h.merge({key => value})
      end
    save
  end

  private def check_value(value)
    if (hash = value.as_h?)
      if hash["expiry"].as_i > Time.utc.to_unix
        hash["value"].as_s
      end
    else
      value.as_s
    end
  end

  def string(key)
    check_value(self.body[key])
  end

  def string?(key)
    string(key)
  rescue KeyError
    # ignore
  end

  def delete(key)
    body = self.body.as_h
    if (value = body.delete(key))
      self.body = body
      save
      check_value(value)
    end
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
