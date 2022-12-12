require "http/server"

require "../../models/account"
require "../../models/session"

class HTTP::Server::Context
  property! session : Session

  delegate :account, :account?, :account=, to: session

  def session
    @session ||= (find_session || new_session)
  end

  private def find_session
    if (jwt = check_authorization || check_cookie)
      Session.find_by_jwt?(jwt)
    end
  end

  private def new_session
    Session.new.save.tap do |session|
      jwt = session.generate_jwt
      response.headers["X-Auth-Token"] = jwt
      response.cookies["AuthToken"] = jwt
    end
  end

  # Replaces the existing session with a new, authenticated session.
  #
  def new_session(account : Account)
    @session = Session.new(account).save.tap do |session|
      jwt = session.generate_jwt
      response.headers["X-Auth-Token"] = jwt
      response.cookies["AuthToken"] = jwt
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
end
