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
      Balloon.host
    end

    macro home_path
      "/"
    end

    macro search_path
      "/search"
    end

    macro sessions_path
      "/sessions"
    end

    macro back_path
      env.request.headers.fetch("Referer", "/")
    end

    macro remote_activity_path(activity = nil)
      "/remote/activities/#{{{activity}}.try(&.id) || env.params.url["id"]}"
    end

    macro activity_path(activity = nil)
      ((%iri = {{activity}}.try(&.iri)) && URI.parse(%iri).path) || "/activities/#{env.params.url["id"]}"
    end

    macro remote_object_path(object = nil)
      "/remote/objects/#{{{object}}.try(&.id) || env.params.url["id"]}"
    end

    macro object_path(object = nil)
      ((%iri = {{object}}.try(&.iri)) && URI.parse(%iri).path) || "/objects/#{env.params.url["id"]}"
    end

    macro remote_actor_path(actor = nil)
      "/remote/actors/#{{{actor}}.try(&.id) || env.params.url["id"]}"
    end

    macro actor_path(actor = nil)
      ((%iri = {{actor}}.try(&.iri)) && URI.parse(%iri).path) || "/actors/#{env.params.url["id"]}"
    end

    macro actor_relationships_path(actor = nil, relationship = nil)
      "#{actor_path({{actor}})}/#{{{relationship}} || env.params.url["relationship"]}"
    end

    macro outbox_path(actor = nil)
      "#{actor_path({{actor}})}/outbox"
    end

    macro inbox_path(actor = nil)
      "#{actor_path({{actor}})}/inbox"
    end

    macro accepts?(mime_type)
      env.accepts?({{mime_type}})
    end

    # Define a simple response helper.
    #
    macro def_response_helper(name, code, message)
      macro {{name.id}}(message = {{message}}, code = {{code}})
        if accepts?("text/html")
          _message = \{{message}}
          env.response.content_type = "text/html"
          halt env, status_code: \{{code}}, response: render "src/views/pages/generic.html.ecr", "src/views/layouts/default.html.ecr"
        else
          env.response.content_type = "application/json"
          halt env, status_code: \{{code}}, response: %<{"msg":\{{message}}}>
        end
      end
    end

    def_response_helper(ok, 200, "OK")
    def_response_helper(bad_request, 400, "Bad Request")
    def_response_helper(forbidden, 403, "Forbidden")
    def_response_helper(not_found, 404, "Not Found")
    def_response_helper(server_error, 500, "Server Error")

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

    # Sanitizes HTML.
    #
    # For use in views:
    #     <%= s string %>
    #
    macro s(str)
      Balloon::Util.sanitize({{str}})
    end

    # Generates a random, URL-safe identifier.
    #
    # 64 bits should ensure it takes about 5 billion attempts to
    # generate a collision.
    #
    macro id
      Random::Secure.urlsafe_base64(8)
    end

    macro included
      def self.paginate(collection, env)
        path = env.request.path
        query = env.params.query
        page = 1
        begin
          if (p = query["page"].to_i) > 0
            page = p
          end
        rescue ArgumentError | KeyError
        end
        render "./src/views/partials/paginator.html.ecr"
      end
    end
  end
end

require "../controllers/**"
