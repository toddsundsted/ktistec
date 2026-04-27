require "kemal"

module Ktistec::Handler
  # Sets `X-Content-Type-Options: nosniff` on responses for paths
  # under `/uploads/`.
  #
  class UploadHeaders < Kemal::Handler
    def call(env)
      if env.request.path.starts_with?("/uploads/")
        env.response.headers["X-Content-Type-Options"] = "nosniff"
      end
      call_next(env)
    end
  end

  add_handler Handler::UploadHeaders.new
end
