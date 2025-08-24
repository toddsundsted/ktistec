require "ecr"
require "slang"
require "kemal"
require "markd"

# Redefine the `render` macros provided by Kemal.

# Render a view with a layout as the superview.
#
macro render(content, layout)
  # Note: `__content_filename__` and `content_io` are magic variables
  # used by Kemal's implementation of "content_for" and must be in
  # scope for `yield_content` to work.

  __content_filename__ = {{content}}

  content_io = IO::Memory.new
  Ktistec::ViewHelper.embed {{content}}, content_io
  %content = content_io.to_s

  {% layout = "_layout_#{layout.gsub(%r[\/|\.], "_").id}" %}
  Ktistec::ViewHelper.{{layout.id}}(
    env,
    yield_content("title"),
    yield_content("head"),
    %content
  )
end

# Render a view with the given filename.
#
macro render(content)
  String.build do |content_io|
    Ktistec::ViewHelper.embed {{content}}, content_io
  end
end

module Ktistec::ViewHelper
  module ClassMethods
    def depth(object)
      object ? "depth-#{Math.min(object.depth, 9)}" : ""
    end

    def activity(activity)
      activity ? "activity-#{activity.class.to_s.split("::").last.downcase}" : ""
    end

    def object_partial(env, object, actor = object.attributed_to(include_deleted: true), author = actor, *, activity = nil, with_detail = false, for_thread = nil)
      if for_thread
        render "src/views/partials/thread.html.slang"
      elsif with_detail
        render "src/views/partials/detail.html.slang"
      else
        render "src/views/partials/object.html.slang"
      end
    end

    def mention_page_mention_banner(env, mention, follow, count)
      render "src/views/partials/mention_page_mention_banner.html.slang"
    end

    def tag_page_tag_controls(env, hashtag, task, follow, count)
      render "src/views/partials/tag_page_tag_controls.html.slang"
    end

    def thread_page_thread_controls(env, thread, task, follow)
      render "src/views/partials/thread_page_thread_controls.html.slang"
    end

    # NOTE: This method is redefined when running tests. It sets the
    # `max_size` to 20, regardless of account authentication.

    def pagination_params(env)
      max_size = env.account? ? 1000 : 20
      {
        page: Math.max(env.params.query["page"]?.try(&.to_i) || 1, 1),
        size: Math.min(env.params.query["size"]?.try(&.to_i) || 10, max_size)
      }
    end

    def paginate(env, collection)
      query = env.params.query
      page = (p = query["page"]?) && (p = p.to_i) > 0 ? p : 1
      render "src/views/partials/paginator.html.slang"
    end

    # Wraps a string in a link if it is a URL.
    #
    # By default, matches the weird format used by Mastodon:
    # https://github.com/mastodon/mastodon/blob/main/app/lib/text_formatter.rb
    #
    def wrap_link(str, include_scheme = false, length = 30, tag = :a)
      uri = URI.parse(str)
      if (scheme = uri.scheme) && (host = uri.host) && (path = uri.path)
        first = include_scheme ? "#{scheme}://#{host}#{path}" : "#{host}#{path}"
        rest = ""
        if first.size > length
          first, rest = first[0...length], first[length..-1]
        end
        String.build do |io|
          if tag == :a
            io << %Q|<a href="#{str}" target="_blank" rel="ugc">|
          else
            io << %Q|<#{tag}>|
          end
          unless include_scheme
            io << %Q|<span class="invisible">#{scheme}://</span>|
          end
          if rest.presence
            io << %Q|<span class="ellipsis">#{first}</span>|
            io << %Q|<span class="invisible">#{rest}</span>|
          else
            io << %Q|<span>#{first}</span>|
          end
          io << %Q|</#{tag}>|
        end
      else
        str
      end
    end

    def wrap_filter_term(str)
      str = str.gsub(/\\?[%_]/) { %Q|<span class="wildcard">#{$0}</span>| }
      %Q|<span class="ui filter term">#{str}</span>|
    end
  end

  extend ClassMethods

  macro included
    extend ClassMethods
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
  macro form_button(arg1, action = nil, method = "POST", form_id = nil, form_class = "ui inline form", button_id = nil, button_class = "ui button", form_data = nil, button_data = nil, csrf = env.session.string?("csrf"), &block)
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
      {% if form_id %}
        %Q|id="#{{{form_id}}}"|,
      {% end %}
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
      {% if button_id %}
        %Q|id="#{{{button_id}}}"|,
      {% end %}
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

  macro form_tag(model, action, *, method = "POST", form = nil, class _class = "ui form", data = nil, csrf = env.session.string?("csrf"), &block)
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
      {% if method == "POST" && form %}
        {% if form == "data" %}
          %Q|enctype="multipart/form-data"|
        {% elsif form == "urlencoded" %}
          %Q|enctype="application/x-www-form-urlencoded"|
        {% else %}
          {% raise "invalid form encoding: #{form}" %}
        {% end %}
      {% elsif form %}
        {% raise "form encoding may only be specified on POST method" %}
      {% end %}
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

  macro input_tag(label, model, field, class _class = "", type = "text", placeholder = nil, autofocus = nil, data = nil)
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
      %Q|class="#{{{_class}}}"|,
      %Q|type="#{{{type}}}"|,
      %Q|name="#{%name}"|,
      %Q|value="#{%value}"|,
      {% if placeholder %}
        %Q|placeholder="#{{{placeholder}}}"|,
      {% end %}
      {% if autofocus %}
        %Q|autofocus|,
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

  # Renders an ActivityPub collection as JSON-LD.
  #
  macro activity_pub_collection(collection, &block)
    %path = env.request.path
    %query = env.params.query
    %unpaged = !%query["page"]?
    %page = %query["page"]?.try(&.to_i) || 1
    %page = %page > 0 ? %page : 1
    content_io << %Q|{|
    content_io << %Q|"@context":"https://www.w3.org/ns/activitystreams",|
    if %unpaged
      content_io << %Q|"type":"OrderedCollection",|
      content_io << %Q|"id":"#{host}#{%path}",|
      content_io << %Q|"first":{|
      content_io << %Q|"type":"OrderedCollectionPage",|
      %query["page"] = "1"
      content_io << %Q|"id":"#{host}#{%path}?#{%query}",|
    else
      content_io << %Q|"type":"OrderedCollectionPage",|
      content_io << %Q|"id":"#{host}#{%path}?#{%query}",|
      if %page > 1
        %query["page"] = (%page - 1).to_s
        content_io << %Q|"prev":"#{host}#{%path}?#{%query}",|
      end
    end
    if {{collection}}.more?
      %query["page"] = (%page + 1).to_s
      content_io << %Q|"next":"#{host}#{%path}?#{%query}",|
    end
    content_io << %Q|"orderedItems":[|
    {% if block %}
      {{collection}}.each_with_index do |{{block.args.join(",").id}}|
        {{block.body}}
      end
    {% end %}
    content_io << %Q|]|
    if %unpaged
      content_io << %Q|}|
    end
    content_io << %Q|}|
  end

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

  ## Task helpers

  # Returns the task status line.
  #
  macro task_status_line(task, detail = false)
    if !{{task}}.complete
      if {{task}}.backtrace
        "The task failed."
      else
        %now = Time.utc
        String.build do |%io|
          if {{task}}.running
            %io << "Running."
          else
            if (%next_attempt_at = {{task}}.next_attempt_at) && %next_attempt_at > %now
              %io << "The next run is in "
              %io << distance_of_time_in_words(%next_attempt_at, %now)
              %io << "."
            else
              %io << "The next run is imminent."
            end
            if {{detail}}
              if (%last_attempt_at = {{task}}.last_attempt_at) && %last_attempt_at < %now
                %io << " The last run was "
                %io << distance_of_time_in_words(%last_attempt_at, %now)
                %io << " ago."
              end
            end
          end
        end
      end
    end
  end

  # Returns the fetch task status line.
  #
  # If `collection` is specified, also includes the most recent
  # `published` date of posts in that collection.
  #
  macro fetch_task_status_line(task, collection = nil, detail = false)
    if !{{task}}.complete
      if {{task}}.backtrace
        "The task failed."
      else
        %now = Time.utc
        String.build do |%io|
          if {{task}}.running
            %io << "Checking for new posts."
          else
            if (%next_attempt_at = {{task}}.next_attempt_at) && %next_attempt_at > %now
              %io << "The next check for new posts is in "
              %io << distance_of_time_in_words(%next_attempt_at, %now)
              %io << "."
            else
              %io << "The next check for new posts is imminent."
            end
            if {{detail}}
              if (%last_attempt_at = {{task}}.last_attempt_at) && %last_attempt_at < %now
                %io << " The last check was "
                %io << distance_of_time_in_words(%last_attempt_at, %now)
                %io << " ago."
              end
              if (%last_success_at = {{task}}.last_success_at) && %last_success_at < %now
                %io << " The last new post was fetched "
                %io << distance_of_time_in_words(%last_success_at, %now)
                %io << " ago."
              end
            end
          end
          if (%collection = {{collection}}) && (%published = %collection.map(&.published).compact.max?)
            %io << " The most recent post was "
            %io << distance_of_time_in_words(%published, %now)
            %io << " ago."
          end
        end
      end
    end
  end

  ## General purpose helpers

  # Returns the host.
  #
  macro host
    Ktistec.host
  end

  # Sanitizes HTML.
  #
  # For use in views:
  #     <%= s string %>
  #
  macro s(str)
    Ktistec::Util.sanitize({{str}})
  end

  # Transforms the span of time between two different times into
  # words.
  #
  # For use in views:
  #     <%= distance_of_time_in_words(from_time, to_time) %>
  #
  macro distance_of_time_in_words(*args)
    Ktistec::Util.distance_of_time_in_words({{args.splat}})
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

  # Converts Markdown to HTML.
  #
  macro markdown_to_html(markdown)
    Markd.to_html({{markdown}})
  end

  # Generates a random, URL-safe identifier.
  #
  macro id
    Ktistec::Util.id
  end

  ## View helpers

  # The naming below matches the format of automatically generated
  # view helpers. View helpers for partials are *not* automatically
  # generated.

  def self._layout_src_views_layouts_default_html_ecr(env, title, head, content)
    render "src/views/layouts/default.html.ecr"
  end

  def self._view_src_views_partials_actor_panel_html_slang(env, actor)
    render "src/views/partials/actor-panel.html.slang"
  end

  def self._view_src_views_partials_collection_json_ecr(env, collection)
    render "src/views/partials/collection.json.ecr"
  end

  def self._view_src_views_partials_object_content_html_slang(env, object, author, actor, with_detail, for_thread)
    render "src/views/partials/object/content.html.slang"
  end

  def self._view_src_views_partials_object_label_html_slang(env, author, actor)
    render "src/views/partials/object/label.html.slang"
  end

  ## Path helpers

  # notes:
  # 1) path helpers that use other path helpers should do so
  # explicitly via `Ktistec::ViewHelper` so that they can be used
  # without requiring the caller include the `Ktistec::ViewHelper`
  # module.
  # 2) macro conditionals should be used to sequester code paths that
  # require `env` from code paths that do not.

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
    {% if filter %}
      "/filters/#{{{filter}}.id}"
    {% else %}
      "/filters/#{env.params.url["id"]}"
    {% end %}
  end

  macro system_path
    "/system"
  end

  macro metrics_path
    "/metrics"
  end

  macro tasks_path
    "/tasks"
  end

  macro remote_activity_path(activity = nil)
    {% if activity %}
      "/remote/activities/#{{{activity}}.id}"
    {% else %}
      "/remote/activities/#{env.params.url["id"]}"
    {% end %}
  end

  macro activity_path(activity = nil)
    {% if activity %}
      "/activities/#{{{activity}}.uid}"
    {% else %}
      "/activities/#{env.params.url["id"]}"
    {% end %}
  end

  macro anchor(object = nil)
    {% if object %}
      "object-#{{{object}}.id}"
    {% else %}
      "object-#{env.params.url["id"]}"
    {% end %}
  end

  macro objects_path
    "/objects"
  end

  macro remote_object_path(object = nil)
    {% if object %}
      "/remote/objects/#{{{object}}.id}"
    {% else %}
      "/remote/objects/#{env.params.url["id"]}"
    {% end %}
  end

  macro object_path(object = nil)
    {% if object %}
      "/objects/#{{{object}}.uid}"
    {% else %}
      "/objects/#{env.params.url["id"]}"
    {% end %}
  end

  macro remote_thread_path(object = nil, anchor = true)
    {% if anchor %}
      "#{Ktistec::ViewHelper.remote_object_path({{object}})}/thread##{Ktistec::ViewHelper.anchor({{object}})}"
    {% else %}
      "#{Ktistec::ViewHelper.remote_object_path({{object}})}/thread"
    {% end %}
  end

  macro thread_path(object = nil, anchor = true)
    {% if anchor %}
      "#{Ktistec::ViewHelper.object_path({{object}})}/thread##{Ktistec::ViewHelper.anchor({{object}})}"
    {% else %}
      "#{Ktistec::ViewHelper.object_path({{object}})}/thread"
    {% end %}
  end

  macro edit_object_path(object = nil)
    "#{Ktistec::ViewHelper.object_path({{object}})}/edit"
  end

  macro reply_path(object = nil)
    "#{Ktistec::ViewHelper.remote_object_path({{object}})}/reply"
  end

  macro approve_path(object = nil)
    "#{Ktistec::ViewHelper.remote_object_path({{object}})}/approve"
  end

  macro unapprove_path(object = nil)
    "#{Ktistec::ViewHelper.remote_object_path({{object}})}/unapprove"
  end

  macro block_object_path(object = nil)
    "#{Ktistec::ViewHelper.remote_object_path({{object}})}/block"
  end

  macro unblock_object_path(object = nil)
    "#{Ktistec::ViewHelper.remote_object_path({{object}})}/unblock"
  end

  macro follow_thread_path(object = nil)
    "#{Ktistec::ViewHelper.remote_object_path({{object}})}/follow"
  end

  macro unfollow_thread_path(object = nil)
    "#{Ktistec::ViewHelper.remote_object_path({{object}})}/unfollow"
  end

  macro start_fetch_thread_path(object = nil)
    "#{Ktistec::ViewHelper.remote_object_path({{object}})}/fetch/start"
  end

  macro cancel_fetch_thread_path(object = nil)
    "#{Ktistec::ViewHelper.remote_object_path({{object}})}/fetch/cancel"
  end

  macro object_remote_reply_path(object = nil)
    "#{Ktistec::ViewHelper.object_path({{object}})}/remote-reply"
  end

  macro object_remote_like_path(object = nil)
    "#{Ktistec::ViewHelper.object_path({{object}})}/remote-like"
  end

  macro object_remote_share_path(object = nil)
    "#{Ktistec::ViewHelper.object_path({{object}})}/remote-share"
  end

  macro create_translation_object_path(object = nil)
    "#{Ktistec::ViewHelper.remote_object_path({{object}})}/translation/create"
  end

  macro clear_translation_object_path(object = nil)
    "#{Ktistec::ViewHelper.remote_object_path({{object}})}/translation/clear"
  end

  macro remote_actor_path(actor = nil)
    {% if actor %}
      "/remote/actors/#{{{actor}}.id}"
    {% else %}
      "/remote/actors/#{env.params.url["id"]}"
    {% end %}
  end

  macro actor_path(actor = nil)
    {% if actor %}
      "/actors/#{{{actor}}.uid}"
    {% else %}
      "/actors/#{env.params.url["username"]}"
    {% end %}
  end

  macro block_actor_path(actor = nil)
    "#{Ktistec::ViewHelper.remote_actor_path({{actor}})}/block"
  end

  macro unblock_actor_path(actor = nil)
    "#{Ktistec::ViewHelper.remote_actor_path({{actor}})}/unblock"
  end

  macro refresh_remote_actor_path(actor = nil)
    "#{Ktistec::ViewHelper.remote_actor_path({{actor}})}/refresh"
  end

  macro actor_relationships_path(actor = nil, relationship = nil)
    {% if relationship %}
      "#{Ktistec::ViewHelper.actor_path({{actor}})}/#{{{relationship}}}"
    {% else %}
      "#{Ktistec::ViewHelper.actor_path({{actor}})}/#{env.params.url["relationship"]}"
    {% end %}
  end

  macro outbox_path(actor = nil)
    Ktistec::ViewHelper.actor_relationships_path({{actor}}, "outbox")
  end

  macro inbox_path(actor = nil)
    Ktistec::ViewHelper.actor_relationships_path({{actor}}, "inbox")
  end

  macro actor_remote_follow_path(actor = nil)
    "#{Ktistec::ViewHelper.actor_path({{actor}})}/remote-follow"
  end

  macro hashtag_path(hashtag = nil)
    {% if hashtag %}
      "/tags/#{{{hashtag}}}"
    {% else %}
      "/tags/#{env.params.url["hashtag"]}"
    {% end %}
  end

  macro follow_hashtag_path(hashtag = nil)
    "#{Ktistec::ViewHelper.hashtag_path({{hashtag}})}/follow"
  end

  macro unfollow_hashtag_path(hashtag = nil)
    "#{Ktistec::ViewHelper.hashtag_path({{hashtag}})}/unfollow"
  end

  macro start_fetch_hashtag_path(hashtag = nil)
    "#{Ktistec::ViewHelper.hashtag_path({{hashtag}})}/fetch/start"
  end

  macro cancel_fetch_hashtag_path(hashtag = nil)
    "#{Ktistec::ViewHelper.hashtag_path({{hashtag}})}/fetch/cancel"
  end

  macro mention_path(mention = nil)
    {% if mention %}
      "/mentions/#{{{mention}}}"
    {% else %}
      "/mentions/#{env.params.url["mention"]}"
    {% end %}
  end

  macro follow_mention_path(mention = nil)
    "#{Ktistec::ViewHelper.mention_path({{mention}})}/follow"
  end

  macro unfollow_mention_path(mention = nil)
    "#{Ktistec::ViewHelper.mention_path({{mention}})}/unfollow"
  end

  macro remote_interaction_path
    "/remote-interaction"
  end
end
