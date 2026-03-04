require "kemal"

require "./controller"

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
        env.response.cookies["__Host-RedirectPath"] = HTTP::Cookie.new(
          name: "__Host-RedirectPath",
          value: URI.encode_path(env.request.resource),
          http_only: true,
          secure: true,
          samesite: HTTP::Cookie::SameSite::Lax,
          max_age: 5.minutes,
          path: "/",
        )
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
