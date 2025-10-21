require "./errors"
require "../utils/json_rpc"
require "../utils/paths"
require "../models/account"
require "../models/relationship/social/follow"
require "../models/relationship/content/notification/follow/hashtag"
require "../models/relationship/content/notification/follow/mention"
require "../models/relationship/content/notification/follow/thread"
require "../models/tag/hashtag"
require "../models/tag/mention"
require "./resources"

module MCP
  module Tools
    include Utils::Paths

    Log = ::Log.for("mcp")

    alias ToolPropertyDefinition =
      NamedTuple(
        name: String,
        type: String,
        description: String,
        required: Bool,
        matches: Regex?,
        minimum: Int32?,
        maximum: Int32?,
        default: String | Int32 | Bool | Time | Array(String) | Array(Int32) | Array(Bool) | Nil,
        # array-specific properties
        items: String?,           # type of array items ("string", "integer")
        min_items: Int32?,        # minimum array length
        max_items: Int32?,        # maximum array length
        unique_items: Bool?,      # whether array elements must be unique
      )

    alias ToolDefinition =
      NamedTuple(
        name: String,
        description: String,
        properties: Array(ToolPropertyDefinition),
      )

    TOOL_DEFINITIONS = [] of ToolDefinition

    macro def_tool(name, description, properties = [] of ToolPropertyDefinition, &block)
      {% TOOL_DEFINITIONS << {name: name, description: description, properties: properties} %}

      def MCP::Tools.handle_tool_{{name.id}}(params : JSON::Any, account : Account) : JSON::Any
        unless (arguments = params["arguments"]?)
          raise MCPError.new("Missing arguments", JSON::RPC::ErrorCodes::INVALID_PARAMS)
        end

        missing_fields = [] of String
        {% for prop in properties %}
          {% if prop[:required] %}
            missing_fields << {{prop[:name]}} unless arguments[{{prop[:name]}}]?
          {% end %}
        {% end %}
        unless missing_fields.empty?
          raise MCPError.new("Missing #{missing_fields.join(", ")}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
        end

        {% for prop in properties %}
          if (value = arguments[{{prop[:name]}}]?)
            {% if prop[:type] == "integer" %}
              unless value.raw.is_a?(Int32) || value.raw.is_a?(Int64)
                raise MCPError.new("`#{{{prop[:name]}}}` must be an integer", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            {% elsif prop[:type] == "boolean" %}
              unless value.raw.is_a?(Bool)
                raise MCPError.new("`#{{{prop[:name]}}}` must be a boolean", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            {% elsif prop[:type] == "string" %}
              unless value.raw.is_a?(String)
                raise MCPError.new("`#{{{prop[:name]}}}` must be a string", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            {% elsif prop[:type] == "time" %}
              unless value.raw.is_a?(String)
                raise MCPError.new("`#{{{prop[:name]}}}` must be a RFC3339 timestamp", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            {% elsif prop[:type] == "array" %}
              unless value.raw.is_a?(Array)
                raise MCPError.new("`#{{{prop[:name]}}}` must be an array", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            {% end %}
          end
        {% end %}

        {% for prop in properties %}
          {% if prop[:type] == "integer" %}
            if (value = arguments[{{prop[:name]}}]?)
              int_value = value.as_i
              {% if prop[:minimum] %}
                if int_value < {{prop[:minimum]}}
                  raise MCPError.new("`#{{{prop[:name]}}}` must be >= {{prop[:minimum]}}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                end
              {% end %}
              {% if prop[:maximum] %}
                if int_value > {{prop[:maximum]}}
                  raise MCPError.new("`#{{{prop[:name]}}}` must be <= {{prop[:maximum]}}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                end
              {% end %}
            end
          {% elsif prop[:type] == "string" && prop[:matches] %}
            if (value = arguments[{{prop[:name]}}]?)
              string_value = value.as_s
              unless {{prop[:matches]}}.match(string_value)
                raise MCPError.new("`#{{{prop[:name]}}}` format is invalid", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            end
          {% elsif prop[:type] == "time" %}
            if (value = arguments[{{prop[:name]}}]?)
              time_string = value.as_s
              begin
                Time.parse_rfc3339(time_string)
              rescue
                raise MCPError.new("`#{{{prop[:name]}}}` must be a RFC3339 timestamp", JSON::RPC::ErrorCodes::INVALID_PARAMS)
              end
            end
          {% elsif prop[:type] == "array" %}
            if (value = arguments[{{prop[:name]}}]?)
              array_value = value.as_a

              {% if prop[:min_items] %}
                if array_value.size < {{prop[:min_items]}}
                  raise MCPError.new("`#{{{prop[:name]}}}` size must be >= {{prop[:min_items]}}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                end
              {% end %}
              {% if prop[:max_items] %}
                if array_value.size > {{prop[:max_items]}}
                  raise MCPError.new("`#{{{prop[:name]}}}` size must be <= {{prop[:max_items]}}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                end
              {% end %}

              {% if prop[:items] %}
                array_value.each_with_index do |item, index|
                  {% if prop[:items] == "string" %}
                    unless item.raw.is_a?(String)
                      raise MCPError.new("`#{{{prop[:name]}}}[#{index}]` must be a string", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                    end
                  {% elsif prop[:items] == "integer" %}
                    unless item.raw.is_a?(Int32) || item.raw.is_a?(Int64)
                      raise MCPError.new("`#{{{prop[:name]}}}[#{index}]` must be an integer", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                    end
                  {% elsif prop[:items] == "boolean" %}
                    unless item.raw.is_a?(Bool)
                      raise MCPError.new("`#{{{prop[:name]}}}[#{index}]` must be a boolean", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                    end
                  {% end %}
                end
              {% end %}

              {% if prop[:unique_items] %}
                string_items = array_value.map(&.to_s)
                if string_items.size != string_items.uniq.size
                  raise MCPError.new("`#{{{prop[:name]}}}` items must be unique", JSON::RPC::ErrorCodes::INVALID_PARAMS)
                end
              {% end %}
            end
          {% end %}
        {% end %}

        {% for prop in properties %}
            {{prop[:name].id}} =
          {% if prop[:required] %} \
            {% if prop[:type] == "string" %}
              arguments[{{prop[:name]}}].as_s
            {% elsif prop[:type] == "integer" %}
              arguments[{{prop[:name]}}].as_i
            {% elsif prop[:type] == "boolean" %}
              arguments[{{prop[:name]}}].as_bool
            {% elsif prop[:type] == "time" %}
              Time.parse_rfc3339(arguments[{{prop[:name]}}].as_s)
            {% elsif prop[:type] == "array" %}
              {% if prop[:items] == "string" %}
                arguments[{{prop[:name]}}].as_a.map(&.as_s)
              {% elsif prop[:items] == "integer" %}
                arguments[{{prop[:name]}}].as_a.map(&.as_i)
              {% elsif prop[:items] == "boolean" %}
                arguments[{{prop[:name]}}].as_a.map(&.as_bool)
              {% else %}
                arguments[{{prop[:name]}}].as_a
              {% end %}
            {% end %}
          {% else %}
            {% if prop[:type] == "string" %}
              arguments[{{prop[:name]}}]?.try(&.as_s) || {{prop[:default]}}
            {% elsif prop[:type] == "integer" %}
              arguments[{{prop[:name]}}]?.try(&.as_i) || {{prop[:default]}}
            {% elsif prop[:type] == "boolean" %}
              arguments[{{prop[:name]}}]?.try(&.as_bool) || {{prop[:default]}}
            {% elsif prop[:type] == "time" %}
              arguments[{{prop[:name]}}]? ? Time.parse_rfc3339(arguments[{{prop[:name]}}].as_s) : {{prop[:default]}}
            {% elsif prop[:type] == "array" %}
              {% if prop[:items] == "string" %}
                arguments[{{prop[:name]}}]?.try(&.as_a.map(&.as_s)) || {{prop[:default]}}
              {% elsif prop[:items] == "integer" %}
                arguments[{{prop[:name]}}]?.try(&.as_a.map(&.as_i)) || {{prop[:default]}}
              {% elsif prop[:items] == "boolean" %}
                arguments[{{prop[:name]}}]?.try(&.as_a.map(&.as_bool)) || {{prop[:default]}}
              {% else %}
                arguments[{{prop[:name]}}]?.try(&.as_a) || {{prop[:default]}}
              {% end %}
            {% end %}
          {% end %}
        {% end %}

        {% if block %}
            {{block.body}}
        {% else %}
            {
              {% for prop in properties %}
                {{prop[:name].id}}: {{prop[:name].id}},
              {% end %}
            }
        {% end %}
      end
    end

    NAME_REGEX = /^([a-zA-Z0-9_-]+|hashtag#[a-zA-Z0-9_-]+|mention@[a-zA-Z0-9_@.-]+)$/

    def_tool(
      "paginate_collection",
      "Paginate through collections of ActivityPub objects, activities, and actors. Use this tool when you want to inspect the contents of a collection.", [
        {name: "name", type: "string", description: "Name of the collection to paginate", required: true, matches: NAME_REGEX},
        {name: "page", type: "integer", description: "Page number (optional, defaults to 1)", minimum: 1, default: 1},
        {name: "size", type: "integer", description: "Number of items per page (optional, defaults to 10, maximum 1000)", minimum: 1, maximum: 20, default: 10},
    ]) do
      unless account.reload!
        raise MCPError.new("Account not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      Log.debug { "paginate_collection: user=#{mcp_user_path(account)} collection=#{name} page=#{page} size=#{size}" }

      actor = account.actor

      objects, more =
        case name
        when "notifications"
          notifications = actor.notifications(page: page, size: size)
          objects = notifications.map do |notification|
            notification_to_json_any(notification)
          end
          {objects.compact, notifications.more?}
        when "timeline"
          timeline = actor.timeline(page: page, size: size)
          objects = timeline.map do |rel|
            JSON::Any.new(MCP::Resources.object_contents(rel.object))
          end
          {objects, timeline.more?}
        when "posts"
          posts = actor.all_posts(page: page, size: size)
          objects = posts.map do |post|
            JSON::Any.new(MCP::Resources.object_contents(post))
          end
          {objects, posts.more?}
        when "drafts"
          drafts = actor.drafts(page: page, size: size)
          objects = drafts.map do |draft|
            JSON::Any.new(MCP::Resources.object_contents(draft))
          end
          {objects, drafts.more?}
        when "likes"
          likes = actor.likes(page: page, size: size)
          objects = likes.map do |liked_object|
            JSON::Any.new(MCP::Resources.object_contents(liked_object))
          end
          {objects, likes.more?}
        when "announces"
          announces = actor.announces(page: page, size: size)
          objects = announces.map do |announced_object|
            JSON::Any.new(MCP::Resources.object_contents(announced_object))
          end
          {objects, announces.more?}
        when "followers"
          followers = Relationship::Social::Follow.followers_for(actor.iri, page: page, size: size)
          objects = followers.map do |relationship|
            JSON::Any.new({
              "actor" => JSON::Any.new(mcp_actor_path(relationship.actor)),
              "confirmed" => JSON::Any.new(relationship.confirmed)
            })
          end
          {objects, followers.more?}
        when "following"
          following = Relationship::Social::Follow.following_for(actor.iri, page: page, size: size)
          objects = following.map do |relationship|
            JSON::Any.new({
              "actor" => JSON::Any.new(mcp_actor_path(relationship.object)),
              "confirmed" => JSON::Any.new(relationship.confirmed)
            })
          end
          {objects, following.more?}
        else
          if name.starts_with?("hashtag#")
            hashtag = name.sub("hashtag#", "")
            hashtag_objects = Tag::Hashtag.all_objects(hashtag, page: page, size: size)
            objects = hashtag_objects.map do |obj|
              JSON::Any.new(MCP::Resources.object_contents(obj))
            end
            {objects, hashtag_objects.more?}
          elsif name.starts_with?("mention@")
            mention = name.sub("mention@", "")
            mention_objects = Tag::Mention.all_objects(mention, page: page, size: size)
            objects = mention_objects.map do |obj|
              JSON::Any.new(MCP::Resources.object_contents(obj))
            end
            {objects, mention_objects.more?}
          else
            raise MCPError.new("`#{name}` unsupported", JSON::RPC::ErrorCodes::INVALID_PARAMS)
          end
        end

      result_data = {
        "objects" => objects.to_a,
        "more" => more,
      }

      JSON::Any.new({
        "content" => JSON::Any.new([JSON::Any.new({
          "type" => JSON::Any.new("text"),
          "text" => JSON::Any.new(result_data.to_json)
        })])
      })
    end

    def_tool(
      "count_collection_since",
      "Count items in ActivityPub collections since a given time. Use this tool when you want to know if new items have been added in the last day/week/month.", [
        {name: "name", type: "string", description: "Name of the collection to count", required: true, matches: NAME_REGEX},
        {name: "since", type: "time", description: "Time (RFC3339) to count from", required: true},
    ]) do
      unless account.reload!
        raise MCPError.new("Account not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      Log.debug { "count_collection_since: user=#{mcp_user_path(account)} collection=#{name} since=#{since}" }

      current_time = Time.utc
      actor = account.actor

      count =
        case name
        when "notifications"
          actor.notifications(since: since)
        when "timeline"
          actor.timeline(since: since)
        when "posts"
          actor.all_posts(since: since)
        when "drafts"
          actor.drafts(since: since)
        when "likes"
          actor.likes(since: since)
        when "announces"
          actor.announces(since: since)
        when "followers"
          Relationship::Social::Follow.followers_since(actor.iri, since)
        when "following"
          Relationship::Social::Follow.following_since(actor.iri, since)
        else
          if name.starts_with?("hashtag#")
            hashtag = name.sub("hashtag#", "")
            Tag::Hashtag.all_objects(hashtag, since)
          elsif name.starts_with?("mention@")
            mention = name.sub("mention@", "")
            Tag::Mention.all_objects(mention, since)
          else
            raise MCPError.new("`#{name}` unsupported", JSON::RPC::ErrorCodes::INVALID_PARAMS)
          end
        end

      result_data = {
        "counted_at" => current_time.to_rfc3339,
        "count" => count,
      }

      JSON::Any.new({
        "content" => JSON::Any.new([JSON::Any.new({
          "type" => JSON::Any.new("text"),
          "text" => JSON::Any.new(result_data.to_json)
        })])
      })
    end

    def_tool(
      "read_resources",
      "Read one or more resources by URI (format \"ktistec://{resource}/{id*}\"). Supports all resource types including " \
      "templated resources (actors, objects) and static resources (information, users). Supports batched reads (comma-separated " \
      "IDs of resources of the same type). Use this tool as a universal fallback when resources are not supported by an MCP " \
      "client.", [
        {name: "uris", type: "array", description: "Resource URIs to read (e.g., ['ktistec://actors/123,456', 'ktistec://objects/456,789'])", required: true, items: "string"},
    ]) do
      Log.debug { "read_resources: user=#{mcp_user_path(account)} uris=#{uris}" }

      resources_data = uris.map do |uri|

        # NOTE: create a fake JSON::RPC::Request to reuse existing resource reading logic
        fake_params = JSON::Any.new({
          "uri" => JSON::Any.new(uri)
        })
        fake_request = JSON::RPC::Request.new(
          "resources/read",
          "fake-id",
          fake_params
        )

        # reuse existing handle_resources_read logic
        result = MCP::Resources.handle_resources_read(fake_request, account)
        contents = result["contents"].as_a

        # extract the resource data from each content item
        contents.map do |content|
          resource_data = JSON.parse(content["text"].as_s)
          {
            "uri" => content["uri"],
            "data" => resource_data
          }
        end
      end.flatten

      result_data = {
        "resources" => resources_data,
      }

      JSON::Any.new({
        "content" => JSON::Any.new([JSON::Any.new({
          "type" => JSON::Any.new("text"),
          "text" => JSON::Any.new(result_data.to_json)
        })])
      })
    end

    def self.handle_tools_list(request : JSON::RPC::Request) : JSON::Any
      {% begin %}
      tools = [
        {% for tool in TOOL_DEFINITIONS %}
          JSON::Any.new({
            "name" => JSON::Any.new({{tool[:name]}}),
            "description" => JSON::Any.new({{tool[:description]}}),
            "inputSchema" => JSON::Any.new({
              "type" => JSON::Any.new("object"),
              "properties" => JSON::Any.new({
                {% for prop in tool[:properties] %}
                  {% if prop[:type] == "array" %}
                    {{prop[:name]}} => JSON::Any.new({
                      "type" => JSON::Any.new("array"),
                      "description" => JSON::Any.new({{prop[:description]}}),
                      {% if prop[:items] %}
                        "items" => JSON::Any.new({
                          "type" => JSON::Any.new({{prop[:items]}})
                        }),
                      {% end %}
                      {% if prop[:min_items] %}
                        "minItems" => JSON::Any.new({{prop[:min_items]}}),
                      {% end %}
                      {% if prop[:max_items] %}
                        "maxItems" => JSON::Any.new({{prop[:max_items]}}),
                      {% end %}
                      {% if prop[:unique_items] %}
                        "uniqueItems" => JSON::Any.new({{prop[:unique_items]}}),
                      {% end %}
                    }),
                  {% else %}
                    {{prop[:name]}} => JSON::Any.new({
                      "type" => JSON::Any.new({{prop[:type] == "time" ? "string" : prop[:type]}}),
                      "description" => JSON::Any.new({{prop[:description]}}),
                      {% if prop[:minimum] %}
                        "minimum" => JSON::Any.new({{prop[:minimum]}}),
                      {% end %}
                      {% if prop[:maximum] %}
                        "maximum" => JSON::Any.new({{prop[:maximum]}}),
                      {% end %}
                    }),
                  {% end %}
                {% end %}
              }),
              "required" => JSON::Any.new([
                {% for prop in tool[:properties] %}
                  {% if prop[:required] %}
                    JSON::Any.new({{prop[:name]}}),
                  {% end %}
                {% end %}
              ])
            })
          }),
        {% end %}
      ]

      JSON::Any.new({
        "tools" => JSON::Any.new(tools)
      })
      {% end %}
    end

    def self.handle_tools_call(request : JSON::RPC::Request, account : Account) : JSON::Any
      unless (params = request.params)
        raise MCPError.new("Missing params", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
      unless (name = params["name"]?.try(&.as_s))
        raise MCPError.new("Missing tool name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      Log.debug { "calling tool: #{name}" }

      case name
      when "paginate_collection"
        handle_tool_paginate_collection(params, account)
      when "count_collection_since"
        handle_tool_count_collection_since(params, account)
      when "read_resources"
        handle_tool_read_resources(params, account)
      else
        Log.warn { "unknown tool: #{name}" }
        raise MCPError.new("Invalid tool name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
    end

    private def self.notification_to_json_any(notification) : JSON::Any?
      case notification
      when Relationship::Content::Notification::Mention
        JSON::Any.new({
          "type" => JSON::Any.new("mention"),
          "object" => JSON::Any.new(mcp_object_path(notification.object)),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_object_path(notification.object)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      when Relationship::Content::Notification::Reply
        JSON::Any.new({
          "type" => JSON::Any.new("reply"),
          "object" => JSON::Any.new(mcp_object_path(notification.object)),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_object_path(notification.object)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      when Relationship::Content::Notification::Follow
        response = notification.activity.as(ActivityPub::Activity::Follow).accepted_or_rejected?
        status = response ?
          "#{response.class.name.split("::").last.downcase}ed" :
          "new"
        JSON::Any.new({
          "type" => JSON::Any.new("follow"),
          "status" => JSON::Any.new(status),
          "actor" => JSON::Any.new(mcp_actor_path(notification.activity.actor)),
          "object" => JSON::Any.new(mcp_user_path(notification.owner)),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_actor_path(notification.activity.actor)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      when Relationship::Content::Notification::Like
        JSON::Any.new({
          "type" => JSON::Any.new("like"),
          "actor" => JSON::Any.new(mcp_actor_path(notification.activity.actor)),
          "object" => JSON::Any.new(mcp_object_path(notification.activity.object)),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_object_path(notification.activity.object)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      when Relationship::Content::Notification::Announce
        JSON::Any.new({
          "type" => JSON::Any.new("announce"),
          "actor" => JSON::Any.new(mcp_actor_path(notification.activity.actor)),
          "object" => JSON::Any.new(mcp_object_path(notification.activity.object)),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_object_path(notification.activity.object)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      when Relationship::Content::Notification::Follow::Hashtag
        JSON::Any.new({
          "type" => JSON::Any.new("follow_hashtag"),
          "hashtag" => JSON::Any.new(notification.name),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{hashtag_path(notification.name)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      when Relationship::Content::Notification::Follow::Mention
        JSON::Any.new({
          "type" => JSON::Any.new("follow_mention"),
          "mention" => JSON::Any.new(notification.name),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{mention_path(notification.name)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      when Relationship::Content::Notification::Follow::Thread
        JSON::Any.new({
          "type" => JSON::Any.new("follow_thread"),
          "thread" => JSON::Any.new(notification.object.thread),
          "action_url" => JSON::Any.new("#{Ktistec.host}#{remote_thread_path(notification.object, anchor: false)}"),
          "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
        })
      end
    end
  end
end
