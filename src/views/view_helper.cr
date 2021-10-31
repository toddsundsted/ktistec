require "../framework/controller"

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
      else
        render "src/views/partials/object.html.slang"
      end
    end

    def pagination_params(env)
      {
        Math.max(env.params.query["page"]?.try(&.to_i) || 1, 1),
        Math.min(env.params.query["size"]?.try(&.to_i) || 10, 1000)
      }
    end

    def paginate(env, collection)
      query = env.params.query
      page = (p = query["page"]?) && (p = p.to_i) > 0 ? p : 1
      render "./src/views/partials/paginator.html.slang"
    end
  end

  macro included
    extend ClassMethods
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
end
