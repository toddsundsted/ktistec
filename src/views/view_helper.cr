require "ecr"
require "slang"

module Ktistec::ViewHelper
  module ClassMethods
    def depth(object)
      object ? "depth-#{Math.min(object.depth, 9)}" : ""
    end

    def activity(activity)
      activity ? "activity-#{activity.class.to_s.split("::").last.downcase}" : ""
    end

    def object_partial(env, object, actor = object.attributed_to, author = actor, *, activity = nil, with_detail = false, for_thread = nil)
      if for_thread
        render "src/views/partials/thread.html.slang"
      elsif with_detail
        render "src/views/partials/detail.html.slang"
      else
        render "src/views/partials/object.html.slang"
      end
    end

    def pagination_params(env)
      {
        page: Math.max(env.params.query["page"]?.try(&.to_i) || 1, 1),
        size: Math.min(env.params.query["size"]?.try(&.to_i) || 10, 1000)
      }
    end

    def paginate(env, collection)
      query = env.params.query
      page = (p = query["page"]?) && (p = p.to_i) > 0 ? p : 1
      render "./src/views/partials/paginator.html.slang"
    end

    def maybe_wrap_link(str)
      if str =~ %r{^[a-zA-Z0-9]+://}
        uri = URI.parse(str)
        port = uri.port.nil? ? "" : ":" + uri.port.to_s
        path = uri.path.nil? ? "" : uri.path.to_s

        # match the weird format used by mastodon
        # see: https://github.com/mastodon/mastodon/blob/main/app/lib/text_formatter.rb#L72
        <<-LINK.gsub(/(\n|^ +)/, "")
        <a href="#{str}" target="_blank" rel="nofollow noopener noreferrer me">
        <span class="invisible">#{uri.scheme}://</span><span class="">#{uri.host}#{port}#{path}</span>
        <span class="invisible"></span>
        </a>
        LINK
      else
        str
      end
    end

    def wrap_filter_term(str)
      str = str.gsub(/\\?[%_]/) { %Q|<span class="wildcard">#{$0}</span>| }
      %Q|<span class="ui filter term">#{str}</span>|
    end
  end

  macro included
    extend ClassMethods
  end

  # the following two macros were copied from kemal and kilt.
  # copying them here was necessary because kilt was removed from
  # kemal. we depended on kilt for rendering slang templates. see:
  # https://github.com/kemalcr/kemal/pull/618

  # Render a view with a layout as the superview.
  #
  macro render(content, layout)
    __content_filename__ = {{content}}

    content_io = IO::Memory.new
    embed {{content}}, content_io
    content = content_io.to_s

    {% if layout %}
      layout_io = IO::Memory.new
      embed {{layout}}, layout_io
      layout_io.to_s
    {% else %}
      content
    {% end %}
  end

  # Render a view with the given filename.
  #
  macro render(content)
    String.build do |content_io|
      embed {{content}}, content_io
    end
  end

  # Embed a view with the given filename.
  #
  macro embed(filename, io_name)
    {% ext = filename.split(".").last %}
    {% if ext == "ecr" %}
      ECR.embed {{filename}}, {{io_name}}
    {% elsif ext == "slang" %}
      Slang.embed {{filename}}, {{io_name}}
    {% else %}
      {% raise "unsupported template extension: #{ext.id}" %}
    {% end %}
  end

  ## Parameter coercion

  macro id_param(env, type = :url, name = "id")
    begin
      env.params.{{type.id}}[{{name.id.stringify}}].to_i64
    rescue ArgumentError
      bad_request
    end
  end

  macro iri_param(env, path = nil, type = :url, name = "id")
    begin
      Base64.decode(%id = env.params.{{type.id}}[{{name.id.stringify}}])
      %path = {{path}} || {{env}}.request.path.split("/")[0..-2].join("/")
      "#{host}#{%path}/#{%id}"
    rescue Base64::Error
      bad_request
    end
  end

  ## HTML helpers

  # Posts an activity to an outbox.
  #
  macro activity_button(arg1, arg2, arg3, type = nil, method = "POST", public = true, form_class = "ui inline form", button_class = "ui button", form_data = nil, button_data = nil, csrf = env.session.string?("csrf"), &block)
    {% if block %}
      {% action = arg1 ; object = arg2 ; type = arg3 %}
      %block =
        begin
          {{block.body}}
        end
    {% else %}
      {% action = arg2 ; object = arg3 ; text = arg1 %}
      %block = {{text}}
    {% end %}
    {% if method == "DELETE" %}
      {% method = "POST" %}
      %input = %q|<input type="hidden" name="_method" value="delete">|
    {% else %}
      %input = ""
    {% end %}
    {% if csrf && method != "GET" %}
     %csrf = %Q|<input type="hidden" name="authenticity_token" value="#{{{csrf}}}">|
    {% else %}
      %csrf = ""
    {% end %}
    %form_attrs = [
      %Q|class="#{{{form_class}}}"|,
      %Q|action="#{{{action}}}"|,
      %Q|method="#{{{method}}}"|,
      {% if form_data %}
        {% for key, value in form_data %}
          %Q|data-{{key.id}}="#{{{value}}}"|,
        {% end %}
      {% end %}
    ]
    %button_attrs = [
      %Q|class="#{{{button_class}}}"|,
      {% if button_data %}
        {% for key, value in button_data %}
          %Q|data-{{key.id}}="#{{{value}}}"|,
        {% end %}
      {% end %}
    ]
    <<-HTML
    <form #{%form_attrs.join(" ")}>\
    #{%csrf}\
    #{%input}\
    <input type="hidden" name="object" value="#{{{object}}}">\
    <input type="hidden" name="type" value="#{{{type || text}}}">\
    <input type="hidden" name="public" value="#{{{public}} ? 1 : nil}">\
    <button #{%button_attrs.join(" ")} type="submit">\
    #{%block}\
    </button>\
    </form>
    HTML
  end

  # General purpose form-powered button.
  #
  macro form_button(arg1, action = nil, method = "POST", form_class = "ui inline form", button_class = "ui button", form_data = nil, button_data = nil, csrf = env.session.string?("csrf"), &block)
    {% if block %}
      {% action = arg1 %}
      %block =
        begin
          {{block.body}}
        end
    {% else %}
      %block = {{arg1}}
    {% end %}
    {% if method == "DELETE" %}
      {% method = "POST" %}
      %input = %q|<input type="hidden" name="_method" value="delete">|
    {% else %}
      %input = ""
    {% end %}
    {% if csrf && method != "GET" %}
     %csrf = %Q|<input type="hidden" name="authenticity_token" value="#{{{csrf}}}">|
    {% else %}
      %csrf = ""
    {% end %}
    %form_attrs = [
      %Q|class="#{{{form_class}}}"|,
      %Q|action="#{{{action}}}"|,
      %Q|method="#{{{method}}}"|,
      {% if form_data %}
        {% for key, value in form_data %}
          %Q|data-{{key.id}}="#{{{value}}}"|,
        {% end %}
      {% end %}
    ]
    %button_attrs = [
      %Q|class="#{{{button_class}}}"|,
      {% if button_data %}
        {% for key, value in button_data %}
          %Q|data-{{key.id}}="#{{{value}}}"|,
        {% end %}
      {% end %}
    ]
    <<-HTML
    <form #{%form_attrs.join(" ")}>\
    #{%csrf}\
    #{%input}\
    <button #{%button_attrs.join(" ")} type="submit">\
    #{%block}\
    </button>\
    </form>
    HTML
  end

  macro authenticity_token(env)
    %Q|<input type="hidden" name="authenticity_token" value="#{{{env}}.session.string?("csrf")}">|
  end

  macro error_messages(model)
    if (%errors = {{model}}.errors.presence)
      %messages = %errors.transform_keys(&.split(".").last).flat_map do |k, vs|
        vs.map { |v| "#{k} #{v}" }
      end.join(", ")
      %Q|<div class="ui error message"><div class="header">#{%messages}</div></div>|
    else
      ""
    end
  end

  macro form_tag(model, action, method = "POST", class _class = "ui form", data = nil, csrf = env.session.string?("csrf"), &block)
    {% if model %}
      %classes =
        {{model}}.errors.presence ?
          "#{{{_class}}} error" :
          {{_class}}
    {% else %}
      %classes = {{_class}}
    {% end %}
    {% if method == "DELETE" %}
      {% method = "POST" %}
      %input = %q|<input type="hidden" name="_method" value="delete">|
    {% else %}
      %input = ""
    {% end %}
    {% if csrf && method != "GET" %}
     %csrf = %Q|<input type="hidden" name="authenticity_token" value="#{{{csrf}}}">|
    {% else %}
      %csrf = ""
    {% end %}
    %block =
      begin
        {{block.body}}
      end
    %attributes = [
      %Q|class="#{%classes}"|,
      %Q|action="#{{{action}}}"|,
      %Q|method="#{{{method}}}"|,
      {% if data %}
        {% for key, value in data %}
          %Q|data-{{key.id}}="#{{{value}}}"|,
        {% end %}
      {% end %}
    ]
    <<-HTML
    <form #{%attributes.join(" ")}>\
    #{%csrf}\
    #{%input}\
    #{%block}\
    </form>
    HTML
  end

  macro input_tag(label, model, field, class _class = "", type = "text", placeholder = nil, data = nil)
    {% if model %}
      %classes =
        {{model}}.errors.has_key?("{{field.id}}") ?
          "field error" :
          "field"
      %name = {{field.id.stringify}}
      %value = {{model}}.{{field.id}}.try { |string| HTML.escape(string) }
    {% else %}
      %classes = "field"
      %name = {{field.id.stringify}}
      %value = nil
    {% end %}
    %attributes = [
      %Q|class="#{{{_class}}}"|,
      %Q|type="#{{{type}}}"|,
      %Q|name="#{%name}"|,
      %Q|value="#{%value}"|,
      {% if placeholder %}
        %Q|placeholder="#{{{placeholder}}}"|,
      {% end %}
      {% if data %}
        {% for key, value in data %}
          %Q|data-{{key.id}}="#{{{value}}}"|,
        {% end %}
      {% end %}
    ]
    <<-HTML
    <div class="#{%classes}">\
    <label>#{{{label}}}</label>\
    <input #{%attributes.join(" ")}>\
    </div>
    HTML
  end

  macro select_tag(label, model, field, options, selected = nil, class _class = "ui selection dropdown", data = nil)
    {% if model %}
      %classes =
        {{model}}.errors.has_key?("{{field.id}}") ?
          "field error" :
          "field"
      %name = {{field.id.stringify}}
      %selected = {{model}}.{{field.id}}
    {% else %}
      %classes = "field"
      %name = {{field.id.stringify}}
      %selected = {{selected}}
    {% end %}
    %attributes = [
      %Q|class="#{{{_class}}}"|,
      %Q|name="#{%name}"|,
      {% if data %}
        {% for key, value in data %}
          %Q|data-{{key.id}}="#{{{value}}}"|,
        {% end %}
      {% end %}
    ]
    %options = {{options}}.map do |key, value|
      if %selected && %selected.to_s == key.to_s
        %Q|<option value="#{key}" selected>#{value}</option>|
      else
        %Q|<option value="#{key}">#{value}</option>|
      end
    end
    <<-HTML
    <div class="#{%classes}">\
    <label>#{{{label}}}</label>\
    <select #{%attributes.join(" ")}>#{%options.join("")}</select>\
    </div>
    HTML
  end

  macro submit_button(value = "Submit", class _class = "ui primary button")
    %Q|<input class="#{{{_class}}}" type="submit" value="#{{{value}}}">|
  end

  macro params_to_inputs(params, exclude exclude_ = nil, include include_ = nil)
    {{params}}.map do |%name, %value|
      if (%exclude = {{exclude_}})
        next if %exclude.includes?(%name)
      end
      if (%include = {{include_}})
        next unless %include.includes?(%name)
      end
      %Q|<input type="hidden" name="#{%name}" value="#{%value}">|
    end.join
  end

  ## JSON helpers

  macro error_block(model, comma = true)
    if (%errors = {{model}}.errors.presence)
      %comma = {{comma}} ? "," : ""
      %errors = %errors.transform_keys(&.split(".").last).to_json
      %Q|"errors":#{%errors}#{%comma}|
    else
      ""
    end
  end

  macro field_pair(model, field, comma = true)
    %comma = {{comma}} ? "," : ""
    %value = {{model}}.{{field.id}}.try(&.inspect) || "null"
    %Q|"{{field.id}}":#{%value}#{%comma}|
  end

  ## General purpose helpers

  # Sanitizes HTML.
  #
  # For use in views:
  #     <%= s string %>
  #
  macro s(str)
    Ktistec::Util.sanitize({{str}})
  end

  # Pluralizes the noun.
  #
  # Important note: if the count is zero, the noun is returned as is,
  # without a quantity (e.g. "fox" not "0 foxes").
  #
  # For use in views:
  #     <%= pluralize(1, "fox") %>
  #
  macro pluralize(count, noun)
    case {{count}}
    when 0
      {{noun}}
    when 1
      "1 #{{{noun}}}"
    else
      "#{{{count}}} #{Ktistec::Util.pluralize({{noun}})}"
    end
  end

  # Emits a comma when one would be necessary when iterating through
  # a collection.
  #
  macro comma(collection, counter)
    {{counter}} < {{collection}}.size - 1 ? "," : ""
  end

  # Generates a random, URL-safe identifier.
  #
  macro id
    Ktistec::Util.id
  end

  ## Path helpers

  macro back_path
    env.request.headers.fetch("Referer", "/")
  end

  macro home_path
    "/"
  end

  macro everything_path
    "/everything"
  end

  macro sessions_path
    "/sessions"
  end

  macro search_path
    "/search"
  end

  macro settings_path
    "/settings"
  end

  macro filters_path
    "/filters"
  end

  macro filter_path(filter = nil)
    "/filters/#{{{filter}}.try(&.id) || env.params.url["id"]}"
  end

  macro metrics_path
    "/metrics"
  end

  macro remote_activity_path(activity = nil)
    "/remote/activities/#{{{activity}}.try(&.id) || env.params.url["id"]}"
  end

  macro activity_path(activity = nil)
    "/activities/#{{{activity}}.try(&.uid) || env.params.url["id"]}"
  end

  macro anchor(object = nil)
    "object-#{{{object}}.try(&.id) || env.params.url["id"]}"
  end

  macro objects_path
    "/objects"
  end

  macro remote_object_path(object = nil)
    "/remote/objects/#{{{object}}.try(&.id) || env.params.url["id"]}"
  end

  macro object_path(object = nil)
    "/objects/#{{{object}}.try(&.uid) || env.params.url["id"]}"
  end

  macro remote_thread_path(object = nil)
    "#{remote_object_path({{object}})}/thread##{anchor({{object}})}"
  end

  macro thread_path(object = nil)
    "#{object_path({{object}})}/thread##{anchor({{object}})}"
  end

  macro edit_object_path(object = nil)
    "#{object_path({{object}})}/edit"
  end

  macro reply_path(object = nil)
    "#{remote_object_path({{object}})}/reply"
  end

  macro approve_path(object = nil)
    "#{remote_object_path({{object}})}/approve"
  end

  macro unapprove_path(object = nil)
    "#{remote_object_path({{object}})}/unapprove"
  end

  macro block_object_path(object = nil)
    "#{remote_object_path({{object}})}/block"
  end

  macro unblock_object_path(object = nil)
    "#{remote_object_path({{object}})}/unblock"
  end

  macro follow_thread_path(object = nil)
    "#{remote_object_path({{object}})}/follow"
  end

  macro unfollow_thread_path(object = nil)
    "#{remote_object_path({{object}})}/unfollow"
  end

  macro remote_actor_path(actor = nil)
    "/remote/actors/#{{{actor}}.try(&.id) || env.params.url["id"]}"
  end

  macro actor_path(actor = nil)
    "/actors/#{{{actor}}.try(&.uid) || env.params.url["username"]}"
  end

  macro block_actor_path(actor = nil)
    "#{remote_actor_path({{actor}})}/block"
  end

  macro unblock_actor_path(actor = nil)
    "#{remote_actor_path({{actor}})}/unblock"
  end

  macro actor_relationships_path(actor = nil, relationship = nil)
    "#{actor_path({{actor}})}/#{{{relationship}} || env.params.url["relationship"]}"
  end

  macro outbox_path(actor = nil)
    actor_relationships_path({{actor}}, "outbox")
  end

  macro inbox_path(actor = nil)
    actor_relationships_path({{actor}}, "inbox")
  end

  macro actor_remote_follow_path(actor = nil)
    "#{actor_path({{actor}})}/remote-follow"
  end

  macro hashtag_path(hashtag = nil)
    "/tags/#{{{hashtag}} || env.params.url["hashtag"]}"
  end

  macro follow_hashtag_path(hashtag = nil)
    "#{hashtag_path({{hashtag}})}/follow"
  end

  macro unfollow_hashtag_path(hashtag = nil)
    "#{hashtag_path({{hashtag}})}/unfollow"
  end
end
