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

    macro accepts?(mime_type)
      env.accepts?({{mime_type}})
    end

    macro bad_request
      if accepts?("text/html")
        env.response.content_type = "text/html"
        halt env, status_code: 400, response: render "src/views/pages/bad_request.html.ecr", "src/views/layouts/default.html.ecr"
      else
        env.response.content_type = "application/json"
        halt env, status_code: 400, response: %<{"msg":"Bad Request"}>
      end
    end

    macro forbidden
      if accepts?("text/html")
        env.response.content_type = "text/html"
        halt env, status_code: 403, response: render "src/views/pages/forbidden.html.ecr", "src/views/layouts/default.html.ecr"
      else
        env.response.content_type = "application/json"
        halt env, status_code: 403, response: %<{"msg":"Forbidden"}>
      end
    end

    macro not_found
      if accepts?("text/html")
        env.response.content_type = "text/html"
        halt env, status_code: 404, response: render "src/views/pages/not_found.html.ecr", "src/views/layouts/default.html.ecr"
      else
        env.response.content_type = "application/json"
        halt env, status_code: 404, response: %<{"msg":"Not Found"}>
      end
    end

    macro server_error
      if accepts?("text/html")
        env.response.content_type = "text/html"
        halt env, status_code: 500, response: render "src/views/pages/server_error.html.ecr", "src/views/layouts/default.html.ecr"
      else
        env.response.content_type = "application/json"
        halt env, status_code: 500, response: %<{"msg":"Server Error"}>
      end
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

    # Sanitizes HTML.
    #
    # For use in views:
    #     <%= s string %>
    #
    macro s(str)
      Balloon::Util.sanitize({{str}})
    end

    macro included
      def self.paginate(collection, env)
        path = env.request.path
        query = env.params.query
        page = 0
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
