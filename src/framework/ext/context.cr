require "http/server"

require "../../models/account"
require "../../models/session"
require "../../models/oauth2/provider/access_token"

class HTTP::Server::Context
  property! session : Session

  delegate :account, :account?, :account=, to: session

  # Returns an existing session or creates a new session.
  #
  # New sessions are only saved to the database when used (e.g. when a
  # CSRF token is stored in the session).
  #
  def session
    @session ||= find_session
  end

  private def find_session : Session
    if (bearer_token = check_authorization)
      find_session_from_bearer_token(bearer_token)
    elsif (jwt = check_cookie)
      find_session_from_jwt(jwt)
    else
      new_session
    end
  end

  private def check_authorization
    if (value = request.headers["Authorization"]?)
      if value.starts_with?("Bearer ")
        value.split(" ").last
      end
    end
  end

  private def check_cookie
    request.cookies["__Host-AuthToken"]?.try(&.value)
  end

  private def find_session_from_bearer_token(token : String)
    token.count('.') == 2 ? find_session_from_jwt(token) : find_session_from_oauth_token(token)
  end

  private def find_session_from_jwt(jwt : String) : Session
    Session.find_by_jwt?(jwt) || new_session
  end

  private def find_session_from_oauth_token(token : String) : Session
    if (access_token = OAuth2::Provider::AccessToken.find_by_token?(token)) && access_token.valid?
      access_token.session? || new_session(access_token)
    else
      new_session
    end
  end

  # Returns a new, nonpersistent, authenticated session.
  #
  private def new_session(access_token : OAuth2::Provider::AccessToken)
    Session.new(account: access_token.account, oauth_access_token: access_token)
  end

  # Returns a new, nonpersistent, anonymous session.
  #
  private def new_session
    Session.new.tap do |session|
      jwt = session.generate_jwt
      __assign_cookie(jwt)
    end
  end

  # Replaces the existing session with a new, persistent,
  # authenticated session.
  #
  def new_session(account : Account)
    @session = Session.new(account).save.tap do |session|
      jwt = session.generate_jwt
      __assign_cookie(jwt)
    end
  end

  private def __assign_cookie(jwt)
    response.cookies["__Host-AuthToken"] = HTTP::Cookie.new(
      name: "__Host-AuthToken",
      value: jwt,
      path: "/",
      max_age: 30.days,
      http_only: true,
      secure: true,
    )
  end
end
