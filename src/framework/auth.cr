require "kemal"

require "./controller"

module Ktistec
  # Authentication middleware.
  #
  class Auth < Kemal::Handler
    include Ktistec::Controller

    def call(env)
      return call_next(env) unless env.route_lookup.found?
      return call_next(env) if env.session.account? || exclude_match?(env)

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
