require "ecr"
require "slang"
require "kemal"
require "markd"

require "../utils/emoji"
require "../utils/paths"

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
    yield_content("og_metadata"),
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
  include Utils::Paths

  module ClassMethods
    def depth(object)
      object ? "depth-#{Math.min(object.depth, 9)}" : ""
    end

    def activity_type_class(activity)
      activity ? "activity-#{activity.class.to_s.split("::").last.downcase}" : ""
    end

    def actor_type_class(actor)
      actor ? "actor-#{actor.class.to_s.split("::").last.downcase}" : ""
    end

    def object_type_class(object)
      object ? "object-#{object.class.to_s.split("::").last.downcase}" : ""
    end

    def object_states(object)
      states = [] of String
      states << "is-sensitive" if object.sensitive
      states << "is-draft" if object.draft?
      states << "is-deleted" if object.deleted?
      states << "is-blocked" if object.blocked?
      states << "has-replies" if object.replies_count > 0
      states << "has-media" if object.attachments.try { |a| a.size > 0 }
      if (attributed_to = object.attributed_to?)
        states << "visibility-#{visibility(attributed_to, object)}"
      end
      states
    end

    def actor_states(object, author, actor, followed_actors)
      states = [] of String
      if followed_actors
        states << "author-followed-by-me" if author && followed_actors.includes?(author.iri)
        states << "actor-followed-by-me" if actor && actor != author && followed_actors.includes?(actor.iri)
      end
      states
    end

    def mention_states(object, actor)
      states = [] of String
      object_mentions = object.mentions
      is_mentioned = object_mentions.any? { |m| m.href == actor.iri }
      if is_mentioned
        states << (object_mentions.size == 1 ? "mentions-only-me" : "mentions-me")
      end
      states
    end

    def object_data_attributes(object, author, actor, followed_hashtags, followed_mentions)
      attrs = {} of String => String
      if (id = object.id)
        attrs["data-object-id"] = id.to_s
      end
      if author
        attrs["data-author-handle"] = author.handle
        attrs["data-author-iri"] = author.iri
      end
      if actor && actor != author
        attrs["data-actor-handle"] = actor.handle
        attrs["data-actor-iri"] = actor.iri
      end
      if followed_hashtags
        object_hashtags = object.hashtags.map(&.name.downcase)
        matched = object_hashtags.select { |hashtag| followed_hashtags.includes?(hashtag) }
        if matched.presence
          attrs["data-followed-hashtags"] = matched.join(" ")
        end
      end
      if followed_mentions
        object_mentions = object.mentions.map(&.name.downcase)
        matched = object_mentions.select { |mention| followed_mentions.includes?(mention) }
        if matched.presence
          attrs["data-followed-mentions"] = matched.join(" ")
        end
      end
      attrs
    end

    def object_partial(env, object, actor = object.attributed_to(include_deleted: true), author = actor, *, activity = nil, with_detail = false, for_thread = nil, for_actor = nil, highlight = false)
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

    PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

    # Derives visibility and to/cc addressing from the "visibility"
    # param.
    #
    def addressing(params, actor)
      to = Set(String).new
      cc = Set(String).new
      case (visibility = params.fetch("visibility", "private"))
      when "public"
        to << PUBLIC
        if (followers = actor.followers)
          cc << followers
        end
      when "private"
        if (followers = actor.followers)
          to << followers
        end
      else
        # not public, no followers
      end
      {visibility == "public", to, cc}
    end

    # Derives visibility from to/cc addressing.
    #
    # If the object has explicit addressing, uses that. Otherwise, if
    # the object is a reply, inherits from the parent: public posts
    # are public, everything else is direct.  Otherwise, defaults to
    # public.
    #
    def visibility(actor, object)
      if (addresses = [object.to, object.cc].compact).presence
        addresses = addresses.flatten
        if addresses.includes?(PUBLIC)
          "public"
        elsif addresses.includes?(actor.followers)
          "private"
        else
          "direct"
        end
      elsif (in_reply_to = object.in_reply_to?) && (addresses = [in_reply_to.to, in_reply_to.cc].compact).presence
        addresses.flatten.includes?(PUBLIC) ? "public" : "direct"
      else
        "public"
      end
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

    # Returns a tuple of {count, color, tooltip} for actor notifications.
    #
    def notification_count_and_color(actor, since : Time?)
      count = actor.notifications(since: since)
      label_color = "yellow"
      tooltip = false
      if count > 0
        notifications = actor.notifications(size: count)
        groups =
          notifications.group_by do |notification|
            case notification
            in Relationship::Content::Notification::Follow
              "follow"
            in Relationship::Content::Notification::Reply
              "reply"
            in Relationship::Content::Notification::Mention
              "mention"
            in Relationship::Content::Notification::Announce, Relationship::Content::Notification::Like, Relationship::Content::Notification::Dislike
              "social"
            in Relationship::Content::Notification::Follow::Hashtag, Relationship::Content::Notification::Follow::Mention, Relationship::Content::Notification::Follow::Thread, Relationship::Content::Notification::Poll::Expiry
              "content"
            in Relationship::Content::Notification
              "other"
            end
          end
        if groups.has_key?("follow") || groups.has_key?("reply") || groups.has_key?("mention")
          label_color = "red"
        elsif groups.has_key?("social")
          label_color = "orange"
        end
        type_order = ["follow", "reply", "mention", "social", "content", "other"]
        tooltip = groups.to_a.sort_by { |type, _| type_order.index(type) || 99 }.map { |type, items| "#{type} #{items.size}" }.join(" | ")
      end
      {count, label_color, tooltip}
    end

    ACTOR_COLOR_COUNT = 12

    def actor_icon(actor, classes = nil)
      if actor
        if actor.deleted?
          src = "/images/avatars/deleted.png"
          alt = "Deleted user"
        elsif actor.blocked?
          src = "/images/avatars/blocked.png"
          alt = "Blocked user"
        elsif !actor.down? && (icon = actor.icon.presence)
          src = icon
          alt = actor.display_name
        else
          if (actor_id = actor.id)
            color = actor_id % ACTOR_COLOR_COUNT
            src = "/images/avatars/color-#{color}.png"
            alt = actor.display_name
          else
            src = "/images/avatars/fallback.png"
            alt = "User"
          end
        end
      else
        src = "/images/avatars/fallback.png"
        alt = "User"
      end
      attrs = [
        %Q|src="#{src}"|,
        %Q|alt="#{::HTML.escape(alt)}"|,
      ]
      attrs.push %Q|data-actor-id="#{actor.id}"| if actor && actor.id
      attrs.unshift %Q|class="#{classes}"| if classes
      %Q|<img #{attrs.join(" ")}>|
    end

    def actor_type(actor)
      icon = if actor
        case actor.type.split("::").last
        when "Person"
          "user"
        when "Group"
          "users"
        when "Organization"
          "university"
        when "Service"
          "plug"
        when "Application"
          "laptop"
        else
          "user"
        end
      else
        "user"
      end
      %Q|<i class="actor-type-overlay #{icon} icon"></i>|
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
    <input type="hidden" name="visibility" value="#{{{public}} ? "public" : "private"}">\
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
      %Q|class="#{{{_class}}}"|,
      %Q|type="#{{{type}}}"|,
      %Q|name="#{%name}"|,
      %Q|value="#{%value}"|,
      {% if id %}
        %Q|id="#{{{id}}}"|,
      {% end %}
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
      %Q|class="#{{{_class}}}"|,
      %Q|name="#{%name}"|,
      %Q|rows="#{{{rows}}}"|,
      {% if id %}
        %Q|id="#{{{id}}}"|,
      {% end %}
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
      %Q|class="#{{{_class}}}"|,
      %Q|name="#{%name}"|,
      {% if id %}
        %Q|id="#{{{id}}}"|,
      {% end %}
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
      %Q|data-controller="editor--trix"|,
      %Q|input="#{%id}"|,
      {% if _class %}
        %Q|class="#{{{_class}}}"|,
      {% end %}
    ]
    %textarea_attributes = [
      %Q|id="#{%id}"|,
      %Q|name="#{%name}"|,
      %Q|rows="4"|,
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

  # Renders HTML as plain text by stripping out all HTML.
  #
  # For use in views:
  #     <%= t string %>
  #
  macro t(str)
    Ktistec::Util.render_as_text({{str}})
  end

  # Renders HTML as plain text and truncates it to `n` characters.
  #
  # For use in views:
  #     <%= … string, n %>
  #
  macro …(str, n)
    Ktistec::Util.render_as_text_and_truncate({{str}}, {{n}})
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

  def self._layout_src_views_layouts_default_html_ecr(env, title, og_metadata, head, content)
    render "src/views/layouts/default.html.ecr"
  end

  def self._view_src_views_partials_actor_panel_html_slang(env, actor)
    render "src/views/partials/actor-panel.html.slang"
  end

  def self._view_src_views_partials_collection_json_ecr(env, collection)
    render "src/views/partials/collection.json.ecr"
  end

  def self._view_src_views_partials_object_content_html_slang(env, object, author, actor, with_detail, for_thread, for_actor)
    render "src/views/partials/object/content.html.slang"
  end

  def self._view_src_views_partials_object_label_html_slang(env, author, actor)
    render "src/views/partials/object/label.html.slang"
  end
end
