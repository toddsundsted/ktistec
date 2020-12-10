require "http/server"

require "../jwt"

class HTTP::Server::Context
  property! session : Session

  delegate :account, :account?, :account=, to: session

  def session
    @session ||= find_session || new_session
  end

  private def find_session
    if (jwt = check_authorization || check_cookie)
      if (payload = Ktistec::JWT.decode(jwt))
        unless Ktistec::JWT.expired?(payload)
          if (session = Session.find(session_key: payload["jti"].as_s))
            return session
          end
        end
      end
    end
  rescue Ktistec::JWT::Error | Ktistec::Model::NotFound
  end

  private def new_session
    session = Session.new.save
    payload = {"jti" => session.session_key, "iat" => Time.utc}
    jwt = Ktistec::JWT.encode(payload)
    response.headers["X-Auth-Token"] = jwt
    response.cookies["AuthToken"] = jwt
    session
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
