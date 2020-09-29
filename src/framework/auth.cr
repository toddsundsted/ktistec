require "./framework"

class HTTP::Server::Context
  property? current_account : Account?
  property? current_session : Session?
end

module Ktistec
  # Authentication middleware.
  #
  class Auth < Kemal::Handler
    include Ktistec::Controller

    def call(env)
      return call_next(env) unless env.route_lookup.found?

      begin
        if (value = check_authorization(env) || check_cookie(env))
          if payload = Ktistec::JWT.decode(value)
            if Time.parse_iso8601(payload["iat"].as_s) > Time.utc - 1.month
              if session = Session.find(session_key: payload["jti"].as_s)
                env.current_account = session.account
                env.current_session = session
                return call_next(env)
              end
            end
          end
        end
      rescue Ktistec::JWT::Error | Ktistec::Model::NotFound
      end

      return call_next(env) if exclude_match?(env)

      _message = "Unauthorized"
      if env.accepts?("text/html")
        env.response.status_code = 401
        env.response.headers["Content-Type"] = "text/html"
        env.response.print render "src/views/pages/generic.html.ecr", "src/views/layouts/default.html.ecr"
      else
        env.response.status_code = 401
        env.response.headers["Content-Type"] = "application/json"
        env.response.print %<{"msg":"#{_message}"}>
      end
    end

    private def check_authorization(env)
      if value = env.request.headers["Authorization"]?
        if value.size > 0 && value.starts_with?("Bearer ")
          value.split(" ").last
        end
      end
    end

    private def check_cookie(env)
      if value = env.request.headers["Cookie"]?
        if value.size > 0 && value.includes?("AuthToken=")
          value.split("; ").find(&.starts_with?("AuthToken")).try(&.split("=").last)
        end
      end
    end
  end

  add_handler Auth.new
end
