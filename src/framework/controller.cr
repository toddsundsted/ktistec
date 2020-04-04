require "kemal"

module Balloon
  module Controller
    macro host
      Balloon.config.host
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
  end
end

require "../controllers/**"
