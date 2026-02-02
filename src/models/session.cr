require "json"

require "../framework/jwt"
require "../framework/model"
require "../framework/model/**"
require "./account"
require "./oauth2/provider/access_token"

# Client session.
#
class Session
  include Ktistec::Model
  include Ktistec::Model::Common

  @[Persistent]
  property session_key : String { Random::Secure.urlsafe_base64 }

  @[Persistent]
  property body_json : String { "{}" }

  @[Persistent]
  property account_id : Int64?
  belongs_to account

  @[Persistent]
  property oauth_access_token_id : Int64?
  belongs_to oauth_access_token, class_name: OAuth2::Provider::AccessToken, inverse_of: :session

  # Allocates a new session for an account.
  #
  def self.new(_account account : Account)
    new(account: account)
  end

  # Removes every session associated with an account.
  #
  def self.invalidate_for(account : Account)
    exec("DELETE FROM sessions WHERE account_id = ?", account.id)
  end

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
    check_value(self.body[key]) || raise KeyError.new(%Q|Missing hash key: "#{key}"|)
  end

  def string?(key)
    check_value(self.body[key])
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

  def self.clean_up_stale_sessions
    delete = <<-QUERY
      DELETE FROM sessions
       WHERE (account_id IS NULL AND updated_at < datetime('now', '-1 hour'))
          OR (updated_at < datetime('now', '-1 month'))
    QUERY
    exec(delete)
  end
end
