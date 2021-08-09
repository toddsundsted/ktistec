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
  end

  macro included
    extend ClassMethods
  end

  ## HTML helpers

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

  macro form_tag(model, action, method = "POST", &block)
    {% if model %}
      %classes =
        {{model}}.errors.presence ?
          "ui form error" :
          "ui form"
    {% else %}
      %classes = "ui form"
    {% end %}
    %block =
      begin
        {{block.body}}
      end
    <<-HTML
    <form class="#{%classes}" action="#{{{action}}}" method="#{{{method}}}">\
    #{%block}\
    </form>
    HTML
  end

  macro input_tag(label, model, field, class _class = "", type _type = "text", placeholder = "")
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
    <<-HTML
    <div class="#{%classes}">\
    <label>#{{{label}}}</label>\
    <input class="#{{{_class}}}" type="#{{{_type}}}" name="#{%name}" value="#{%value}" placeholder="#{{{placeholder}}}">\
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
