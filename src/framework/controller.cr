require "kemal"

class HTTP::Server::Context
  def accepts?(mime_type)
    @accepts ||=
      if self.request.headers["Accept"]?
        self.request.headers["Accept"].split(",").map(&.split(";").first)
      elsif self.request.headers["Content-Type"]?
        [self.request.headers["Content-Type"].split(";").first]
      else
        [] of String
      end
    if accepts = @accepts
      accepts.includes?(mime_type)
    end
  end
end

module Balloon
  module Controller
    macro host
      Balloon.config.host
    end

    macro accepts?(mime_type)
      env.accepts?({{mime_type}})
    end

    macro bad_request
      body = {msg: "Bad Request"}
      env.response.content_type = "application/json"
      halt env, status_code: 400, response: body.to_json
    end

    macro not_found
      body = {msg: "Not Found"}
      env.response.content_type = "application/json"
      halt env, status_code: 404, response: body.to_json
    end

    macro server_error
      body = {msg: "Server Error"}
      env.response.content_type = "application/json"
      halt env, status_code: 500, response: body.to_json
    end

    # Don't authenticate specified handlers.
    #
    #     skip_auth ["/foo", "/bar"], GET, POST
    #
    macro skip_auth(paths, method = GET, *methods)
      class ::Balloon::Auth < ::Kemal::Handler
        {% for method in (methods << method) %}
          exclude {{paths}}, {{method.stringify}}
        {% end %}
      end
    end

    # Escapes newline characters.
    #
    # For use in views:
    #     <%= e string %>
    #
    macro e(str)
      {{str}}.gsub("\n", "\\n")
    end
  end
end

require "../controllers/**"
