require "kemal"
require "kilt/slang"

require "./ext/context"

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

  def xhr?
    @request.headers["X-Requested-With"]? == "XMLHttpRequest"
  end

  def created(url, status_code = nil, *, body = nil)
    @response.headers.add("Location", url)
    @response.status_code = status_code.nil? ? (accepts?("text/html") && !xhr?) ? 302 : 201 : status_code
    @response.print(body) if body
  end
end

module Ktistec
  module Controller
    macro host
      Ktistec.host
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

    macro settings_path
      "/settings"
    end

    macro back_path
      env.request.headers.fetch("Referer", "/")
    end

    macro remote_activity_path(activity = nil)
      "/remote/activities/#{{{activity}}.try(&.id) || env.params.url["id"]}"
    end

    macro activity_path(activity = nil)
      "/activities/#{{{activity}}.try(&.uid) || env.params.url["id"]}"
    end

    macro objects_path
      "/objects"
    end

    macro remote_object_path(object = nil)
      "/remote/objects/#{{{object}}.try(&.id) || env.params.url["id"]}"
    end

    macro edit_object_path(object = nil)
      "/objects/#{{{object}}.try(&.uid) || env.params.url["id"]}/edit"
    end

    macro object_path(object = nil)
      "/objects/#{{{object}}.try(&.uid) || env.params.url["id"]}"
    end

    macro remote_actor_path(actor = nil)
      "/remote/actors/#{{{actor}}.try(&.id) || env.params.url["id"]}"
    end

    macro actor_path(actor = nil)
      "/actors/#{{{actor}}.try(&.uid) || env.params.url["username"]}"
    end

    macro actor_relationships_path(actor = nil, relationship = nil)
      "#{actor_path({{actor}})}/#{{{relationship}} || env.params.url["relationship"]}"
    end

    macro actor_remote_follow_path(actor = nil)
      "#{actor_path({{actor}})}/remote-follow"
    end

    macro outbox_path(actor = nil)
      "#{actor_path({{actor}})}/outbox"
    end

    macro inbox_path(actor = nil)
      "#{actor_path({{actor}})}/inbox"
    end

    macro anchor(object)
      "object-#{{{object}}.id}"
    end

    macro remote_thread_path(object)
      "/remote/objects/#{{{object}}.id}/thread#object-#{{{object}}.id}"
    end

    macro replies_path(object)
      "/remote/objects/#{{{object}}.id}/replies"
    end

    macro _tag(_io, _name, *contents, **attributes, &block)
      {% if attributes.size > 0 %}
        {{_io}} << %q|<{{_name.id}}|
        {% for k, v in attributes %}
          {{_io}} << " "
          {{_io}} << {{k.stringify}}
          {{_io}} << "="
          {{_io}} << {{v}}.inspect
        {% end %}
        {{_io}} << %q|>|
      {% else %}
        {{_io}} << %q|<{{_name.id}}>|
      {% end %}
      {% for c in contents %}
        {% if c.is_a?(Call) && !c.receiver && c.name == "tag" %}
          {% if c.args && c.named_args %}
            _{{c.name}}({{_io}}, {{*c.args}}, {{*c.named_args}}) {{c.block}}
          {% elsif c.args %}
            _{{c.name}}({{_io}}, {{*c.args}}) {{c.block}}
          {% elsif c.named_args %}
            _{{c.name}}({{_io}}, {{*c.named_args}}) {{c.block}}
          {% else %}
            _{{c.name}}({{_io}}) {{c.block}}
          {% end %}
        {% elsif c.is_a?(Call) || c.is_a?(StringLiteral) %}
          {{_io}} << {{c}}
        {% else %}
          {% raise "Unsupported tag content: #{c}" %}
        {% end %}
      {% end %}
      {% if block %}
        begin
          {{*block.args}} = {{_io}}
          {{block.body}}
        end
      {% end %}
      {{_io}} << "</{{_name.id}}>"
    end

    macro tag(_name, *contents, **attributes, &block)
      String.build do |%io|
        {% if contents.size > 0 && attributes.size > 0 %}
          _tag(%io, {{_name}}, {{*contents}}, {{**attributes}}) {{block}}
        {% elsif contents.size > 0 %}
          _tag(%io, {{_name}}, {{*contents}}) {{block}}
        {% elsif attributes.size > 0 %}
          _tag(%io, {{_name}}, {{**attributes}}) {{block}}
        {% else %}
          _tag(%io, {{_name}}) {{block}}
        {% end %}
      end
    end

    # Posts an activity to an outbox.
    #
    macro activity_button(arg1, arg2, arg3, type = nil, form_class = nil, button_class = nil, &block)
      {% if block %}
        {% outbox_url = arg1 ; object_iri = arg2 ; type = arg3 %}
      {% else %}
        {% outbox_url = arg2 ; object_iri = arg3 ; text = arg1 %}
      {% end %}
      {% form_class = ["ui", "form", form_class].select{ |i| i }.join(" ") %}
      {% button_class = ["ui", "button", button_class].select{ |i| i }.join(" ") %}
      # see BUG: https://github.com/crystal-lang/crystal/issues/10236
      tag(
        :form,
        tag(:input, type: "hidden", name: "authenticity_token", value: env.session.string?("csrf")),
        tag(:input, type: "hidden", name: "type", value: {{type || text}}),
        tag(:input, type: "hidden", name: "object", value: {{object_iri}}),
        {% if block %}
          tag(:button, type: "submit", "class": {{button_class}}) {{block}},
        {% else %}
          tag(:button, {{text}}, type: "submit", "class": {{button_class}}),
        {% end %}
        method: "POST", action: {{outbox_url}},
        "class": {{form_class}}
      )
    end

    macro accepts?(mime_type)
      env.accepts?({{mime_type}})
    end

    macro xhr?
      env.xhr?
    end

    # Define a simple response helper.
    #
    macro def_response_helper(name, message, code)
      macro {{name.id}}(message = {{message}}, code = {{code}})
        if accepts?("text/html")
          _message = \{{message}}
          env.response.content_type = "text/html"
          halt env, status_code: \{{code}}, response: render "src/views/pages/generic.html.ecr", "src/views/layouts/default.html.ecr"
        elsif accepts?("text/plain")
          env.response.content_type = "text/plain"
          halt env, status_code: \{{code}}, response: \{{message}}.downcase
        else
          env.response.content_type = "application/json"
          halt env, status_code: \{{code}}, response: ({msg: \{{message}}.downcase}.to_json)
        end
      end
    end

    def_response_helper(ok, "OK", 200)
    def_response_helper(created, "Created", 201)
    def_response_helper(bad_request, "Bad Request", 400)
    def_response_helper(forbidden, "Forbidden", 403)
    def_response_helper(not_found, "Not Found", 404)
    def_response_helper(conflict, "Conflict", 409)
    def_response_helper(server_error, "Server Error", 500)

    # Don't authenticate specified handlers.
    #
    #     skip_auth ["/foo", "/bar"], GET, POST
    #
    macro skip_auth(paths, method = GET, *methods)
      class ::Ktistec::Auth < ::Kemal::Handler
        {% for method in (methods << method) %}
          exclude {{paths}}, {{method.stringify}}
        {% end %}
      end
    end

    # Sanitizes HTML.
    #
    # For use in views:
    #     <%= s string %>
    #
    macro s(str)
      Ktistec::Util.sanitize({{str}})
    end

    # Emits a comma when one would be necessary when iterating through
    # a collection.
    #
    macro comma(collection, counter)
      {{counter}} < {{collection}}.size - 1 ? "," : ""
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
      def self.pagination_params(env)
        {
          Math.max(env.params.query["page"]?.try(&.to_i) || 1, 1),
          Math.min(env.params.query["size"]?.try(&.to_i) || 10, 1000)
        }
      end

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
