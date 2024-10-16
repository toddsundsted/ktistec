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

    VIEWS = {} of String => {String, String, String?}

    macro register_view(key, view, layout = nil, **opts)
      {%
        unless VIEWS[key]
          VIEWS[key] = {opts.keys.splat, view, layout}
        end
      %}
    end

    macro finished
      {% for name, options in VIEWS %}
        {% opts, view, layout = options %}
        {% if layout %}
          def Ktistec::ViewHelper.{{name.id}}({{opts.id}})
            render {{view}}, {{layout}}
          end
        {% else %}
          def Ktistec::ViewHelper.{{name.id}}({{opts.id}})
            render {{view}}
          end
        {% end %}
      {% end %}
    end

    # Define a simple response helper.
    #
    macro def_response_helper(name, status_message, status_code)
      macro {{name.id}}(_message = {{status_message}}, _status_code = {{status_code}}, _basedir = "src/views", _operation = nil, _target = nil, **opts)
        \{% if _message.is_a?(StringLiteral) && _message.includes?('/') %}
          \{% if file_exists?(view = "#{_basedir.id}/#{_message.id}.json.ecr") %}
            \{% key = "_view_#{view.gsub(%r[\/|\.], "_").id}" %}
            register_view(\{{key}}, \{{view}}, \{{opts.double_splat}})
            if accepts?("application/ld+json", "application/activity+json", "application/json")
              halt env, status_code: \{{_status_code}}, response: ::Ktistec::ViewHelper.\{{key.id}}(\{{opts.double_splat}})
            end
          \{% end %}
          \{% if file_exists?(view = "#{_basedir.id}/#{_message.id}.text.ecr") %}
            \{% key = "_view_#{view.gsub(%r[\/|\.], "_").id}" %}
            register_view(\{{key}}, \{{view}}, \{{opts.double_splat}})
            if accepts?("text/plain")
              halt env, status_code: \{{_status_code}}, response: ::Ktistec::ViewHelper.\{{key.id}}(\{{opts.double_splat}})
            end
          \{% end %}
          \{% if file_exists?(view = "#{_basedir.id}/#{_message.id}.html.slang") %}
            \{% if _operation && _target %}
              if accepts?("text/vnd.turbo-stream.html")
                \{% key = "_view_#{view.gsub(%r[\/|\.], "_").id}" %}
                register_view(\{{key}}, \{{view}}, \{{opts.double_splat}})
                %body = ::Ktistec::ViewHelper.\{{key.id}}(\{{opts.double_splat}})
                %body = %Q|<turbo-stream action="#{\{{_operation}}}" target="#{\{{_target}}}"><template>#{%body}</template></turbo-stream>|
                halt env, status_code: \{{_status_code}}, response: %body
              end
            \{% else %}
              if accepts?("text/html")
                \{% key = "_view_#{view.gsub(%r[\/|\.], "_").id}_layout_src_views_layouts_default_html_ecr" %}
                register_view(\{{key}}, \{{view}}, "src/views/layouts/default.html.ecr", \{{opts.double_splat}})
                %body = ::Ktistec::ViewHelper.\{{key.id}}(\{{opts.double_splat}})
                halt env, status_code: \{{_status_code}}, response: %body
              end
            \{% end %}
          \{% end %}
          \{% if file_exists?(view = "#{_basedir.id}/#{_message.id}.json.ecr") %}
            \{% key = "_view_#{view.gsub(%r[\/|\.], "_").id}" %}
            register_view(\{{key}}, \{{view}}, \{{opts.double_splat}})
            accepts?("application/ld+json", "application/activity+json", "application/json") # sets the content type as a side effect
            halt env, status_code: \{{_status_code}}, response: ::Ktistec::ViewHelper.\{{key.id}}(\{{opts.double_splat}})
          \{% end %}
        \{% else %}
          if accepts?("application/ld+json", "application/activity+json", "application/json")
            halt env, status_code: \{{_status_code}}, response: ({msg: \{{_message}}.downcase}.to_json)
          end
          if accepts?("text/plain")
            halt env, status_code: \{{_status_code}}, response: \{{_message}}.downcase
          end
          \{% if _operation && _target %}
            if accepts?("text/vnd.turbo-stream.html")
              \{% key = "_view_src_views_pages_generic_html_slang" %}
              register_view(\{{key}}, "src/views/pages/generic.html.slang", env: env, message: \{{_message}})
              %body = ::Ktistec::ViewHelper.\{{key.id}}(env: env, message: \{{_message}})
              %body = %Q|<turbo-stream action="#{\{{_operation}}}" target="#{\{{_target}}}"><template>#{%body}</template></turbo-stream>|
              halt env, status_code: \{{_status_code}}, response: %body
            end
          \{% else %}
            if accepts?("text/html")
              \{% key = "_view_src_views_pages_generic_html_slang_layout_src_views_layouts_default_html_ecr" %}
              register_view(\{{key}}, "src/views/pages/generic.html.slang", "src/views/layouts/default.html.ecr", env: env, message: \{{_message}})
              %body = Ktistec::ViewHelper.\{{key.id}}(env: env, message: \{{_message}})
              halt env, status_code: \{{_status_code}}, response: %body
            end
          \{% end %}
          accepts?("application/ld+json", "application/activity+json", "application/json") # sets the content type as a side effect
          halt env, status_code: \{{_status_code}}, response: ({msg: \{{_message}}.downcase}.to_json)
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
