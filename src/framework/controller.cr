require "kemal"

module Balloon
  module Controller
    macro host
      Balloon.config.host
    end

    macro accepts?(mime_type)
      env.get?("accept") && env.get("accept").as(Array(String)).includes?({{mime_type}})
    end

    add_context_storage_type(Array(String))

    before_all do |env|
      if env.request.headers["Accept"]?
        env.set "accept", env.request.headers["Accept"].split(",").map(&.split(";").first)
      else
        [] of String
      end
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

    macro skip_auth(paths, method = "GET")
      class ::Balloon::Auth < ::Kemal::Handler
        exclude {{paths}}, {{method}}
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
