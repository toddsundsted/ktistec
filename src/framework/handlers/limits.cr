require "kemal"

require "../controller"

module Ktistec
  # Request body size limiting middleware.
  #
  # Halts with 413 if the declared `Content-Length` or the body itself
  # exceeds the limit.
  #
  # Must run before any handler that reads the body.
  #
  class Limits < Kemal::Handler
    INBOX_LIMIT         =  1_048_576
    AUTHENTICATED_LIMIT = 12_582_912
    ANONYMOUS_LIMIT     =     16_384

    private INBOX_PATH = /^\/(actors\/[^\/]+\/)?inbox$/

    def call(env)
      return call_next(env) unless (body = env.request.body)

      limit =
        if INBOX_PATH.matches?(env.request.path)
          INBOX_LIMIT
        elsif env.account?
          AUTHENTICATED_LIMIT
        else
          ANONYMOUS_LIMIT
        end

      buffer = IO::Memory.new
      return payload_too_large(env) unless fits?(env, body, buffer, limit)

      env.request.body = buffer.rewind
      call_next(env)
    end

    private def fits?(env, body, buffer, limit)
      if (content_length = env.request.content_length) && content_length > limit
        return false
      end
      IO.copy(body, buffer, limit + 1)
      buffer.size <= limit
    end

    private def payload_too_large(env)
      message = "Payload Too Large"
      env.response.status_code = 413
      if env.accepts?("text/html")
        env.response.headers["Content-Type"] = "text/html"
        env.response.print render "src/views/pages/generic.html.slang", "src/views/layouts/default.html.ecr"
      else
        env.response.headers["Content-Type"] = "application/json"
        env.response.print %<{"msg":"#{message.downcase}"}>
      end
    end
  end

  add_handler Limits.new
end
