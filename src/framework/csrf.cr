# The MIT License (MIT)

# Copyright (c) 2016 Serdar Dogruyol

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require "kemal"

module Ktistec
  # CSRF preventing middleware.
  #
  class CSRF < Kemal::Handler
    def initialize(
         @header = "X-CSRF-Token",
         @allowed_routes = [] of String,
         @allowed_methods = %w(GET HEAD OPTIONS TRACE),
         # these are the only content types/encodings that a browser
         # should be able to submit cross-domain by default. see:
         # https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#simple_requests
         @enforced_content_types = %w(application/x-www-form-urlencoded multipart/form-data text/plain),
         @parameter_name = "authenticity_token",
         @error : String | (HTTP::Server::Context -> String) = "Forbidden (CSRF)"
       )
      setup
    end

    def setup
      @allowed_routes.each do |path|
        class_name = {{@type.name}}
        %w(GET HEAD OPTIONS TRACE PUT POST).each do |method|
          @@exclude_routes_tree.add "#{class_name}/#{method}#{path}", "/#{method}#{path}"
        end
      end
    end

    def call(context)
      return call_next(context) if exclude_match?(context)

      if context.accepts?("text/html")
        unless context.session.string?("csrf")
          csrf_token = Random::Secure.hex(16)
          context.session.string("csrf", csrf_token)
          context.response.cookies << HTTP::Cookie.new(
            name: @parameter_name,
            value: csrf_token,
            expires: Time.local.to_utc + 1.hour,
            http_only: false
          )
        end
      end

      content_type = context.request.headers["Content-Type"]?.try(&.split(";").first.strip.presence)
      return call_next(context) unless content_type.nil? || @enforced_content_types.includes?(content_type)
      return call_next(context) if @allowed_methods.includes?(context.request.method)

      req = context.request
      submitted_token = if req.headers[@header]?
                          req.headers[@header]
                        elsif context.params.body[@parameter_name]?
                          context.params.body[@parameter_name]
                        else
                          "nothing"
                        end
      current_token = context.session.string?("csrf")
      if current_token == submitted_token
        return call_next(context)
      else
        context.response.status_code = 403
        if (error = @error) && !error.is_a?(String)
          context.response.print error.call(context)
        else
          context.response.print error
        end
      end
    end
  end

  add_handler CSRF.new(
    allowed_routes: ["/actors/:username/inbox"]
  )
end
