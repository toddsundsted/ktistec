module Ktistec::ViewHelper
  # Posts an activity to an outbox.
  #
  macro activity_button(arg1, arg2, arg3, type = nil, method = "POST", public = true, form_class = "ui inline form", button_class = "ui button", form_data = nil, button_data = nil, csrf = env.session.csrf_token, &block)
    {% if block %}
      {% action = arg1; object = arg2; type = arg3 %}
      %block =
        begin
          {{block.body}}
        end
    {% else %}
      {% action = arg2; object = arg3; text = arg1 %}
      %block = {{text}}
    {% end %}
    {% if method == "DELETE" %}
      {% method = "POST" %}
      %input = %q(<input type="hidden" name="_method" value="delete">)
    {% else %}
      %input = ""
    {% end %}
    {% if csrf && method != "GET" %}
     %csrf = %Q(<input type="hidden" name="authenticity_token" value="#{{{csrf}}}">)
    {% else %}
      %csrf = ""
    {% end %}
    %form_attrs = [
      %Q(class="#{{{form_class}}}"),
      %Q(action="#{{{action}}}"),
      %Q(method="#{{{method}}}"),
      {% if form_data %}
        {% for key, value in form_data %}
          %Q(data-{{key.id}}="#{{{value}}}"),
        {% end %}
      {% end %}
    ]
    %button_attrs = [
      %Q(class="#{{{button_class}}}"),
      {% if button_data %}
        {% for key, value in button_data %}
          %Q(data-{{key.id}}="#{{{value}}}"),
        {% end %}
      {% end %}
    ]
    <<-HTML
    <form #{%form_attrs.join(" ")}>\
    #{%csrf}\
    #{%input}\
    <input type="hidden" name="object" value="#{{{object}}}">\
    <input type="hidden" name="type" value="#{{{type || text}}}">\
    <input type="hidden" name="visibility" value="#{{{public}} ? "public" : "private"}">\
    <button #{%button_attrs.join(" ")} type="submit">\
    #{%block}\
    </button>\
    </form>
    HTML
  end

  # General purpose form-powered button.
  #
  macro form_button(arg1, action = nil, method = "POST", form_id = nil, form_class = "ui inline form", button_id = nil, button_class = "ui button", form_data = nil, button_data = nil, csrf = env.session.csrf_token, &block)
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
      %input = %q(<input type="hidden" name="_method" value="delete">)
    {% else %}
      %input = ""
    {% end %}
    {% if csrf && method != "GET" %}
     %csrf = %Q(<input type="hidden" name="authenticity_token" value="#{{{csrf}}}">)
    {% else %}
      %csrf = ""
    {% end %}
    %form_attrs = [
      {% if form_id %}
        %Q(id="#{{{form_id}}}"),
      {% end %}
      %Q(class="#{{{form_class}}}"),
      %Q(action="#{{{action}}}"),
      %Q(method="#{{{method}}}"),
      {% if form_data %}
        {% for key, value in form_data %}
          %Q(data-{{key.id}}="#{{{value}}}"),
        {% end %}
      {% end %}
    ]
    %button_attrs = [
      {% if button_id %}
        %Q(id="#{{{button_id}}}"),
      {% end %}
      %Q(class="#{{{button_class}}}"),
      {% if button_data %}
        {% for key, value in button_data %}
          %Q(data-{{key.id}}="#{{{value}}}"),
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
    %Q(<input type="hidden" name="authenticity_token" value="#{{{env}}.session.csrf_token}">)
  end

  macro error_messages(model)
    if (%errors = {{model}}.errors.presence)
      %messages = %errors.transform_keys(&.split(".").last).flat_map do |k, vs|
        vs.map { |v| "#{k} #{v}" }
      end.join(", ")
      %Q(<div class="ui error message"><div class="header">#{%messages}</div></div>)
    else
      ""
    end
  end

  macro form_tag(model, action, *, method = "POST", form = nil, class _class = "ui form", data = nil, csrf = env.session.csrf_token, &block)
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
      %input = %q(<input type="hidden" name="_method" value="delete">)
    {% else %}
      %input = ""
    {% end %}
    {% if csrf && method != "GET" %}
     %csrf = %Q(<input type="hidden" name="authenticity_token" value="#{{{csrf}}}">)
    {% else %}
      %csrf = ""
    {% end %}
    %block =
      begin
        {{block.body}}
      end
    %attributes = [
      %Q(class="#{%classes}"),
      %Q(action="#{{{action}}}"),
      %Q(method="#{{{method}}}"),
      {% if method == "POST" && form %}
        {% if form == "data" %}
          %Q(enctype="multipart/form-data")
        {% elsif form == "urlencoded" %}
          %Q(enctype="application/x-www-form-urlencoded")
        {% else %}
          {% raise "invalid form encoding: #{form}" %}
        {% end %}
      {% elsif form %}
        {% raise "form encoding may only be specified on POST method" %}
      {% end %}
      {% if data %}
        {% for key, value in data %}
          %Q(data-{{key.id}}="#{{{value}}}"),
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

  macro input_tag(label, model, field, id = nil, class _class = "", type = "text", placeholder = nil, autofocus = nil, data = nil)
    {% if model %}
      %classes =
        {{model}}.errors.has_key?("{{field.id}}") ?
          "field error" :
          "field"
      %name = {{field.id.stringify}}
      %value = {{model}}.{{field.id}}.try { |string| ::HTML.escape(string) }
    {% else %}
      %classes = "field"
      %name = {{field.id.stringify}}
      %value = nil
    {% end %}
    %attributes = [
      %Q(class="#{{{_class}}}"),
      %Q(type="#{{{type}}}"),
      %Q(name="#{%name}"),
      %Q(value="#{%value}"),
      {% if id %}
        %Q(id="#{{{id}}}"),
      {% end %}
      {% if placeholder %}
        %Q(placeholder="#{{{placeholder}}}"),
      {% end %}
      {% if autofocus %}
        %Q(autofocus),
      {% end %}
      {% if data %}
        {% for key, value in data %}
          %Q(data-{{key.id}}="#{{{value}}}"),
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

  macro textarea_tag(label, model, field, id = nil, class _class = "", rows = 4, placeholder = nil, autofocus = nil, data = nil)
    {% if model %}
      %classes =
        {{model}}.errors.has_key?("{{field.id}}") ?
          "field error" :
          "field"
      %name = {{field.id.stringify}}
      %value = {{model}}.{{field.id}}.try { |string| ::HTML.escape(string) }
    {% else %}
      %classes = "field"
      %name = {{field.id.stringify}}
      %value = nil
    {% end %}
    %attributes = [
      %Q(class="#{{{_class}}}"),
      %Q(name="#{%name}"),
      %Q(rows="#{{{rows}}}"),
      {% if id %}
        %Q(id="#{{{id}}}"),
      {% end %}
      {% if placeholder %}
        %Q(placeholder="#{{{placeholder}}}"),
      {% end %}
      {% if autofocus %}
        %Q(autofocus),
      {% end %}
      {% if data %}
        {% for key, value in data %}
          %Q(data-{{key.id}}="#{{{value}}}"),
        {% end %}
      {% end %}
    ]
    <<-HTML
    <div class="#{%classes}">\
    <label>#{{{label}}}</label>\
    <textarea #{%attributes.join(" ")}>#{%value}</textarea>\
    </div>
    HTML
  end

  macro select_tag(label, model, field, options, selected = nil, id = nil, class _class = "ui selection dropdown", data = nil)
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
      %Q(class="#{{{_class}}}"),
      %Q(name="#{%name}"),
      {% if id %}
        %Q(id="#{{{id}}}"),
      {% end %}
      {% if data %}
        {% for key, value in data %}
          %Q(data-{{key.id}}="#{{{value}}}"),
        {% end %}
      {% end %}
    ]
    %options = {{options}}.map do |key, value|
      if %selected && %selected.to_s == key.to_s
        %Q(<option value="#{key}" selected>#{value}</option>)
      else
        %Q(<option value="#{key}">#{value}</option>)
      end
    end
    <<-HTML
    <div class="#{%classes}">\
    <label>#{{{label}}}</label>\
    <select #{%attributes.join(" ")}>#{%options.join("")}</select>\
    </div>
    HTML
  end

  macro trix_editor(label, model, field, id = nil, class _class = "")
    {% if model %}
      %classes =
        {{model}}.errors.has_key?("{{field.id}}") ?
          "field error" :
          "field"
      %name = {{field.id.stringify}}
      %value = {{model}}.{{field.id}}.try { |string| ::HTML.escape(string) }
    {% else %}
      %classes = "field"
      %name = {{field.id.stringify}}
      %value = nil
    {% end %}
    %id = {{id}} || "#{%name}-#{Time.utc.to_unix_ms}"
    %trix_editor_attributes = [
      %Q(data-controller="editor--trix"),
      %Q(input="#{%id}"),
      {% if _class %}
        %Q(class="#{{{_class}}}"),
      {% end %}
    ]
    %textarea_attributes = [
      %Q(id="#{%id}"),
      %Q(name="#{%name}"),
      %Q(rows="4"),
    ]
    <<-HTML
    <div class="#{%classes}" data-turbo-permanent>\
    <label>#{{{label}}}</label>\
    <trix-editor #{%trix_editor_attributes.join(" ")}></trix-editor>\
    <textarea #{%textarea_attributes.join(" ")}>#{%value}</textarea>\
    </div>
    HTML
  end

  macro submit_button(value = "Submit", class _class = "ui primary button")
    %Q(<input class="#{{{_class}}}" type="submit" value="#{{{value}}}">)
  end

  macro params_to_inputs(params, exclude exclude_ = nil, include include_ = nil)
    {{params}}.map do |%name, %value|
      if (%exclude = {{exclude_}})
        next if %exclude.includes?(%name)
      end
      if (%include = {{include_}})
        next unless %include.includes?(%name)
      end
      %Q(<input type="hidden" name="#{%name}" value="#{%value}">)
    end.join
  end

  NUMBERS_TO_WORDS = {
     0 => "zero",
     1 => "one",
     2 => "two",
     3 => "three",
     4 => "four",
     5 => "five",
     6 => "six",
     7 => "seven",
     8 => "eight",
     9 => "nine",
    10 => "ten",
    11 => "eleven",
    12 => "twelve",
    13 => "thirteen",
    14 => "fourteen",
    15 => "fifteen",
    16 => "sixteen",
    17 => "seventeen",
    18 => "eighteen",
    19 => "nineteen",
    20 => "twenty",
  }

  # Converts an integer to its word representation.
  #
  # Returns the word for numbers 0-20 and the number itself as a
  # string for numbers outside that range.
  #
  def self.number_to_word(n : Int) : String
    NUMBERS_TO_WORDS[n]? || n.to_s
  end
end
