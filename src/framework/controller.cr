require "kemal"

require "../views/view_helper"

class HTTP::Server::Context
  # Returns a true value if the request accepts, or otherwise
  # indicates, any of the specified mime types.
  #
  # Sets the "Content-Type" header on the response to a compatible
  # value as a side-effect.
  #
  def accepts?(*mime_types)
    @accepts ||=
      if (accept = self.request.headers["Accept"]?)
        accept.split(",").reduce(Hash(String, String).new) do |accepts, content_type|
          accepts.merge({ content_type.split(";").first.strip => content_type })
        end
      elsif (content_type = self.request.headers["Content-Type"]?)
        { content_type.split(";").first.strip => content_type }
      else
        {} of String => String
      end
    if accepts = @accepts
      if (accept = accepts.find(&.first.in?(mime_types)))
        self.response.content_type = accept.last
      end
    end
  end

  def turbo_frame?
    @request.headers.has_key?("Turbo-Frame")
  end

  def created(url, status_code = nil, *, body = nil)
    @response.headers.add("Location", url)
    @response.status_code = status_code.nil? ? accepts?("text/html") ? 302 : 201 : status_code
    @response.print(body) if body
  end
end

module Ktistec
  module Controller
    macro included
      # generally, controllers are going to want to use
      # view helpers in their actions.
      include Ktistec::ViewHelper
    end

    macro host
      Ktistec.host
    end

    macro accepts?(*mime_type)
      env.accepts?({{mime_type.splat}})
    end

    macro turbo_frame?
      env.turbo_frame?
    end

    # Redirect and end processing.
    #
    macro redirect(url, status_code = 302, body = nil)
      env.response.headers.add("Location", {{url}})
      env.response.status_code = {{status_code}}
      {% if body %}
        env.response.print({{body}})
      {% end %}
      env.response.close
      next
    end

    # Define a simple response helper.
    #
    macro def_response_helper(name, message, code)
      macro {{name.id}}(message = nil, code = nil, basedir = "src/views", layout = nil, operation = nil, target = nil)
        \{% if layout && (operation || target) %}
          \{% raise "either layout may be specified, or operation and target" %}
        \{% end %}
        \{% if !layout && !operation && !target %}
          \{% layout = "src/views/layouts/default.html.ecr" %}
        \{% end %}
        \{% if message.is_a?(StringLiteral) && message.includes?('/') %}
          \{% if file_exists?("#{basedir.id}/#{message.id}.json.ecr") %}
            if accepts?("application/ld+json", "application/activity+json", "application/json")
              halt env, status_code: \{{code}} || {{code}}, response: render \{{"#{basedir.id}/#{message.id}.json.ecr"}}
            end
          \{% end %}
          \{% if file_exists?("#{basedir.id}/#{message.id}.text.ecr") %}
            if accepts?("text/plain")
              halt env, status_code: \{{code}} || {{code}}, response: render \{{"#{basedir.id}/#{message.id}.text.ecr"}}
            end
          \{% end %}
          \{% if file_exists?("#{basedir.id}/#{message.id}.html.slang") %}
            \{% if layout %}
              if accepts?("text/html")
                halt env, status_code: \{{code}} || {{code}}, response: render \{{"#{basedir.id}/#{message.id}.html.slang"}}, \{{layout}}
              end
            \{% end %}
            \{% if operation && target %}
              if accepts?("text/vnd.turbo-stream.html")
                %body = render \{{"#{basedir.id}/#{message.id}.html.slang"}}
                %body = %Q|<turbo-stream action="\{{operation.id}}" target="\{{target.id}}"><template>#{%body}</template></turbo-stream>|
                halt env, status_code: \{{code}} || {{code}}, response: %body
              end
            \{% end %}
          \{% end %}
          \{% if file_exists?("#{basedir.id}/#{message.id}.json.ecr") %}
            accepts?("application/ld+json", "application/activity+json", "application/json") # sets the content type as a side effect
            halt env, status_code: \{{code}} || {{code}}, response: render \{{"#{basedir.id}/#{message.id}.json.ecr"}}
          \{% end %}
        \{% else %}
          if accepts?("application/ld+json", "application/activity+json", "application/json")
            halt env, status_code: \{{code}} || {{code}}, response: ({msg: (\{{message}} || {{message}}).downcase}.to_json)
          end
          if accepts?("text/plain")
            halt env, status_code: \{{code}} || {{code}}, response: (\{{message}} || {{message}}).downcase
          end
          \{% if layout %}
            if accepts?("text/html")
              _message = \{{message}} || {{message}}
              halt env, status_code: \{{code}} || {{code}}, response: Ktistec::ViewHelper._view___generic_html_slang__default_html_ecr(env, _message)
            end
          \{% end %}
          \{% if operation && target %}
            if accepts?("text/vnd.turbo-stream.html")
              _message = \{{message}} || {{message}}
              %body = Ktistec::ViewHelper._view___generic_html_slang(env, _message)
              %body = %Q|<turbo-stream action="\{{operation.id}}" target="\{{target.id}}"><template>#{%body}</template></turbo-stream>|
              halt env, status_code: \{{code}} || {{code}}, response: %body
            end
          \{% end %}
          accepts?("application/ld+json", "application/activity+json", "application/json") # sets the content type as a side effect
          halt env, status_code: \{{code}} || {{code}}, response: ({msg: (\{{message}} || {{message}}).downcase}.to_json)
        \{% end %}
      end
    end

    def_response_helper(ok, "OK", 200)
    def_response_helper(created, "Created", 201)
    def_response_helper(bad_request, "Bad Request", 400)
    def_response_helper(forbidden, "Forbidden", 403)
    def_response_helper(not_found, "Not Found", 404)
    def_response_helper(conflict, "Conflict", 409)
    def_response_helper(unprocessable_entity, "Unprocessable Entity", 422)
    def_response_helper(server_error, "Server Error", 500)
    def_response_helper(bad_gateway, "Bad Gateway", 502)

    # Don't authenticate specified handlers.
    #
    # Use at the beginning of a controller.
    #
    #     skip_auth ["/foo", "/bar"], GET, POST
    #
    # Defaults to GET if no other method is specified. Automatically
    # includes HEAD if GET is specified.
    #
    macro skip_auth(paths, method = GET, *methods)
      class ::Ktistec::Auth < ::Kemal::Handler
        {% methods = (methods << method).map(&.stringify) %}
        {% for method in methods %}
          exclude {{paths}}, {{method}}
        {% end %}
        {% if methods.includes?("GET") && !methods.includes?("HEAD") %}
          exclude {{paths}}, "HEAD"
        {% end %}
      end
    end
  end
end
