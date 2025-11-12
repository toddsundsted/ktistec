require "http/server"

require "../../models/account"
require "../../models/session"

class HTTP::Server::Context
  property! session : Session

  delegate :account, :account?, :account=, to: session

  # Returns a new, nonpersistent, unauthenticated session.
  #
  # These sessions are only saved to the database when used (e.g. when
  # a CSRF token is stored in the session).
  #
  def session
    @session ||= (find_session || new_session)
  end

  private def find_session
    if (jwt = check_authorization || check_cookie)
      Session.find_by_jwt?(jwt)
    end
  end

  private def check_authorization
    if value = request.headers["Authorization"]?
      if value.starts_with?("Bearer ")
        value.split(" ").last
      end
    end
  end

  private def check_cookie
    request.cookies["AuthToken"]?.try(&.value)
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
    response.cookies["AuthToken"] = HTTP::Cookie.new(
      name: "AuthToken",
      value: jwt,
      path: "/",
      max_age: 30.days,
      http_only: true,
      secure: true,
    )
  end
end
