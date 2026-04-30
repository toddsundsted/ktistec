module Ktistec::ViewHelper
  module ClassMethods
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
      elsif object.responds_to?(:in_reply_to?) && (in_reply_to = object.in_reply_to?) &&
            (addresses = [in_reply_to.to, in_reply_to.cc].compact).presence
        addresses.flatten.includes?(PUBLIC) ? "public" : "direct"
      else
        "public"
      end
    end

    def wrap_filter_term(str)
      str = ::HTML.escape(str).gsub(/\\?[%_]/) { %Q(<span class="wildcard">#{$0}</span>) }
      %Q(<span class="ui filter term">#{str}</span>)
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
            in Relationship::Content::Notification::Quote
              "quote"
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
        if groups.has_key?("follow") || groups.has_key?("reply") || groups.has_key?("quote") || groups.has_key?("mention")
          label_color = "red"
        elsif groups.has_key?("social")
          label_color = "orange"
        end
        type_order = ["follow", "reply", "mention", "social", "content", "other"]
        tooltip = groups.to_a.sort_by { |type, _| type_order.index(type) || 99 }.map { |type, items| "#{type} #{items.size}" }.join(" | ")
      end
      {count, label_color, tooltip}
    end

    # Normalizes `params` into a consistent hash format.
    #
    def normalize_params(params : URI::Params) : Hash(String, String | Array(String))
      result = Hash(String, String | Array(String)).new
      params.each do |key, _|
        values = params.fetch_all(key).reject(&.empty?)
        next if values.empty?
        if values.size == 1
          result[key] = values.first
        else
          result[key] = values
        end
      end
      result
    end

    # Normalizes `params` into a consistent hash format.
    #
    def normalize_params(params : Hash(String, JSON::Any::Type)) : Hash(String, String | Array(String))
      result = Hash(String, String | Array(String)).new
      params.each do |key, value|
        next if value.nil?
        case value
        when Array
          array_values = value.compact_map do |item|
            next if item.raw.nil?
            case item.raw
            when Int, Float, Bool, String
              item.to_s
            else
              raise "Unsupported value"
            end
          end
          result[key] = array_values unless array_values.empty?
        when Int, Float, Bool, String
          result[key] = value.to_s
        else
          raise "Unsupported value"
        end
      end
      result
    end
  end

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
    Ktistec::Util.sanitize({{ str }})
  end

  # Renders HTML as plain text by stripping out all HTML.
  #
  # For use in views:
  #     <%= t string %>
  #
  macro t(str)
    Ktistec::Util.render_as_text({{ str }})
  end

  # Renders HTML as plain text and truncates it to `n` characters.
  #
  # For use in views:
  #     <%= … string, n %>
  #
  macro …(str, n)
    Ktistec::Util.render_as_text_and_truncate({{ str }}, {{ n }})
  end

  # Transforms the span of time between two different times into
  # words.
  #
  # For use in views:
  #     <%= distance_of_time_in_words(from_time, to_time) %>
  #
  macro distance_of_time_in_words(*args)
    Ktistec::Util.distance_of_time_in_words({{ args.splat }})
  end

  # Wraps a string in a link if it is a URL.
  #
  # By default, matches the weird format used by Mastodon:
  # https://github.com/mastodon/mastodon/blob/main/app/lib/text_formatter.rb
  #
  macro wrap_link(*args, **opts)
    Ktistec::Util.wrap_link({{ args.splat }}, {{ opts.double_splat }})
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
    case {{ count }}
    when 0
      {{ noun }}
    when 1
      "1 #{{{ noun }}}"
    else
      "#{{{ count }}} #{Ktistec::Util.pluralize({{ noun }})}"
    end
  end

  # Emits a comma when one would be necessary when iterating through
  # a collection.
  #
  macro comma(collection, counter)
    {{ counter }} < {{ collection }}.size - 1 ? "," : ""
  end

  # Converts Markdown to HTML.
  #
  macro markdown_to_html(markdown)
    Markd.to_html({{ markdown }})
  end

  # Generates a random, URL-safe identifier.
  #
  macro id
    Ktistec::Util.id
  end

  # Returns the task status line.
  #
  macro task_status_line(task, detail = false)
    if !{{ task }}.complete
      if {{ task }}.backtrace
        "The task failed."
      else
        %now = Time.utc
        String.build do |%io|
          if {{ task }}.running
            %io << "Running."
          else
            if (%next_attempt_at = {{ task }}.next_attempt_at)
              if %next_attempt_at > %now
                %io << "The next run is in "
                %io << distance_of_time_in_words(%next_attempt_at, %now)
                %io << "."
              else
                %io << "The next run is imminent."
              end
            else
              %io << "The task isn't scheduled."
            end
            if {{ detail }}
              if (%last_attempt_at = {{ task }}.last_attempt_at) && %last_attempt_at < %now
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
    if !{{ task }}.complete
      if {{ task }}.backtrace
        "The task failed."
      else
        %now = Time.utc
        String.build do |%io|
          if {{ task }}.running
            %io << "Checking for new posts."
          else
            if (%next_attempt_at = {{ task }}.next_attempt_at)
              if %next_attempt_at > %now
                %io << "The next check for new posts is in "
                %io << distance_of_time_in_words(%next_attempt_at, %now)
                %io << "."
              else
                %io << "The next check for new posts is imminent."
              end
            else
              %io << "The next check for new posts isn't scheduled."
            end
            if {{ detail }}
              if (%last_attempt_at = {{ task }}.last_attempt_at) && %last_attempt_at < %now
                %io << " The last check was "
                %io << distance_of_time_in_words(%last_attempt_at, %now)
                %io << " ago."
              end
              if (%last_success_at = {{ task }}.last_success_at) && %last_success_at < %now
                %io << " The last new post was fetched "
                %io << distance_of_time_in_words(%last_success_at, %now)
                %io << " ago."
              end
            end
          end
          if (%collection = {{ collection }}) && (%published = %collection.map(&.published).compact.max?)
            %io << " The most recent post was "
            %io << distance_of_time_in_words(%published, %now)
            %io << " ago."
          end
        end
      end
    end
  end
end
