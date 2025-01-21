require "kemal"

module Ktistec
  # Authentication middleware.
  #
  class Auth < Kemal::Handler
    def call(env)
      return call_next(env) unless env.route_lookup.found?
      return call_next(env) if env.session.account? || exclude_match?(env)

      # only apply on browser navigation
      if env.request.method == "GET" && env.accepts?("text/html")
        # include both the path and the query in the redirect path
        env.session.string("redirect_after_auth_path", env.request.resource, expires_in: 5.minutes)
      end

      message = "Unauthorized"
      if env.accepts?("text/html")
        env.response.status_code = 401
        env.response.headers["Content-Type"] = "text/html"
        env.response.print render "src/views/pages/generic.html.slang", "src/views/layouts/default.html.ecr"
      else
        env.response.status_code = 401
        env.response.headers["Content-Type"] = "application/json"
        env.response.print %<{"msg":"#{message}"}>
      end
    end
  end

  add_handler Auth.new
end
