require "kemal"

module Ktistec
  # Path rewriting middleware.
  #
  class Rewrite < Kemal::Handler
    def call(env)
      return call_next(env) unless /^\/(@|%40)([a-zA-Z0-9.~_-]+).*/ =~ env.request.path
      env.request.path = "/actors/#{$2}"
      call_next(env)
    end
  end

  add_handler Rewrite.new
end
