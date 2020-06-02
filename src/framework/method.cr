require "./framework"

class HTTP::Server
  class Context
    def params=(@params)
    end
  end
end

module Balloon
  # HTTP method aliasing.
  #
  class Method < Kemal::Handler
    def call(env)
      return call_next env unless env.request.method == "POST"
      return call_next env unless env.params.body["_method"]? == "delete"

      # switch method and fix URL params
      env.request.method = env.params.body["_method"].upcase
      env.params = Kemal::ParamParser.new(env.request, env.route_lookup.params)

      call_next env
    end
  end

  add_handler Method.new
end
