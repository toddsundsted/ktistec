require "kemal"

require "../framework/controller"
require "../models/relationship/content/canonical"

module Ktistec::Handler
  # Canonical path mapping handler.
  #
  class Canonical < Kemal::Handler
    include Ktistec::Controller

    def call(env)
      return call_next(env) unless env.request.method == "GET"

      path = env.request.path
      if (canonical = Relationship::Content::Canonical.find?(to_iri: path)) && accepts?("text/html") && !xhr?
        env.response.headers.add("Cache-Control", "max-age=3600")
        env.redirect canonical.from_iri, 301
      elsif (canonical = Relationship::Content::Canonical.find?(from_iri: path))
        env.request.path = canonical.to_iri
        call_next(env)
      else
        call_next(env)
      end
    end
  end

  add_handler Handler::Canonical.new
end
