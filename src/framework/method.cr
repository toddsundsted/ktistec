require "kemal"

class HTTP::Server
  class Context
    def params=(@params)
    end
  end
end

module Ktistec
  # HTTP method aliasing.
  #
  class Method < Kemal::Handler
    def call(env)
      # don't run this handler for image uploads and inboxes. the use
      # of `env.params.body` below breaks the form data processing in
      # the uploads controller. (note: pixelfed incorrectly specifies
      # "application/x-www-form-urlencoded" on activities. see:
      # https://github.com/pixelfed/pixelfed/issues/3049
      return call_next env unless env.request.method == "POST"
      return call_next env if env.request.path == "/uploads" || env.request.path.ends_with?("/inbox")
      return call_next env unless env.params.body["_method"]? == "delete"

      # switch method and fix URL params
      env.request.method = env.params.body["_method"].upcase
      env.params = Kemal::ParamParser.new(env.request, env.route_lookup.params)

      call_next env
    end
  end

  add_handler Method.new
end
