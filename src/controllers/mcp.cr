require "../framework/controller"
require "../utils/json_rpc"
require "../models/account"
require "../models/activity_pub/object"
require "../models/relationship/social/follow"
require "../models/tag/hashtag"
require "../models/tag/mention"
require "../models/oauth2/provider/access_token"
require "../models/prompt"
require "../views/view_helper"
require "../mcp/resources"
require "../mcp/errors"

require "markd"
class MCPController
  include Ktistec::Controller
  include Ktistec::ViewHelper

  Log = ::Log.for("mcp")

  skip_auth ["/mcp"], OPTIONS, GET, POST # skip the built-in authentication and implement custom authentication

  SERVER_VERSIONS = %w[2024-11-05 2025-03-26 2025-06-18]

  def self.protocol_version(client_version, server_versions = SERVER_VERSIONS)
    client_version.in?(server_versions) ? client_version : server_versions.sort.last
  end

  def self.authenticate_request(env) : Account?
    if (auth_header = env.request.headers["Authorization"]?)
      if auth_header.starts_with?("Bearer ")
        if (access_token = OAuth2::Provider::AccessToken.find?(token: auth_header[7..-1]))
          if access_token.scope.split.includes?("mcp")
            if Time.utc < access_token.expires_at
              access_token.account
            end
          end
        end
      end
    end
  end

  private macro mcp_response(status_code, response)
    env.response.content_type = "application/json"
    halt env, status_code: {{status_code}}, response: {{response}}.try(&.to_json)
  end

  private macro set_headers
    env.response.headers.add("Access-Control-Allow-Origin", "*")
    env.response.headers.add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    env.response.headers.add("Access-Control-Allow-Headers", "Authorization, Content-Type, MCP-Protocol-Version")
    env.response.content_type = "application/json"
  end

  options "/mcp" do |env|
    set_headers

    no_content
  end

  get "/mcp" do |env|
    set_headers

    unauthorized unless authenticate_request(env)

    method_not_allowed ["POST"]
  end

  post "/mcp" do |env|
    set_headers

    unless (account = authenticate_request(env))
      unauthorized
    end

    unless accepts?("application/json")
      bad_request "Bad Request"
    end

    begin
      json = env.request.body.try(&.gets_to_end) || ""

      if json.empty?
        bad_request "Empty Request"
      end

      request = JSON::RPC::Request.from_json(json)
      Log.debug { "new request: method=#{request.method} id=#{request.id}" }

      if request.notification?
        handle_notification(request)
        mcp_response 202, nil
      elsif (response = handle_request(request, account))
        mcp_response 200, response
      else
        Log.warn { "method not found: #{request.method}" }
        error = JSON::RPC::Response::Error.new(JSON::RPC::ErrorCodes::METHOD_NOT_FOUND, "Method not found: #{request.method}")
        error_response = JSON::RPC::Response.new(request.id.not_nil!, error: error)
        mcp_response 404, error_response
      end
    rescue ex: JSON::ParseException
      Log.warn { "parse error: #{ex.message}" }
      error = JSON::RPC::Response::Error.new(JSON::RPC::ErrorCodes::PARSE_ERROR, "Parse error")
      error_response = JSON::RPC::Response.new("null", error: error)
      mcp_response 400, error_response
    rescue err : MCPError
      Log.warn { "MCP error: #{err.message} (code=#{err.code})" }
      error = JSON::RPC::Response::Error.new(err.code, err.message || "Unknown error")
      error_response = JSON::RPC::Response.new(request.try(&.id) || "null", error: error)
      mcp_response 400, error_response
    rescue ex
      Log.warn { "internal error: #{ex.message}" }
      error = JSON::RPC::Response::Error.new(JSON::RPC::ErrorCodes::INTERNAL_ERROR, "Internal error")
      error_response = JSON::RPC::Response.new("null", error: error)
      mcp_response 500, error_response
    end
  end

  private def self.handle_initialize(request : JSON::RPC::Request) : JSON::Any
    client_version = request.params.not_nil!["protocolVersion"].as_s
    server_version = protocol_version(client_version)
    JSON::Any.new({
      "protocolVersion" => JSON::Any.new(server_version),
      "serverInfo" => JSON::Any.new({
        "name" => JSON::Any.new("Ktistec MCP Server"),
        "version" => JSON::Any.new(Ktistec::VERSION)
      }),
      "instructions" => JSON::Any.new(
        "This server provides access to the ActivityPub objects, activities, actors, and collections " \
        "in a Ktistec server. Use tools to paginate through collections (like the user's timeline) and " \
        "to check for (count) new posts. Use resources (or the read resources tool) to read actor profiles " \
        "and replies to posts. These tools are useful for monitoring ActivityPub feeds, tracking new " \
        "content, and analyzing social media activity patterns. The server supports both local and " \
        "federated ActivityPub content, with language translation support, and rich media attachment " \
        "handling. After reading this, the first steps you should take are: 1) list the resources and " \
        "tools this server supports and 2) read the information resource (#{mcp_information_path}) for " \
        "more detail about this server, including collections supported and their naming conventions."
      ),
      "capabilities" => JSON::Any.new({
        "resources" => JSON::Any.new({} of String => JSON::Any),
        "resourceTemplates" => JSON::Any.new({} of String => JSON::Any),
        "tools" => JSON::Any.new({} of String => JSON::Any),
        "prompts" => JSON::Any.new({} of String => JSON::Any),
      }),
    })
  end

  private def self.handle_request(request : JSON::RPC::Request, account : Account) : JSON::RPC::Response?
    request_id = request.id.not_nil!
    Log.debug { "dispatching: method=#{request.method}" }

    case request.method
    when "initialize"
      result = handle_initialize(request)
      JSON::RPC::Response.new(request_id, result)
    when "resources/list"
      result = MCP::Resources.handle_resources_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "resources/read"
      result = MCP::Resources.handle_resources_read(request, account)
      JSON::RPC::Response.new(request_id, result)
    when "resources/templates/list"
      result = MCP::Resources.handle_resources_templates_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "tools/list"
      result = handle_tools_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "tools/call"
      result = handle_tools_call(request, account)
      JSON::RPC::Response.new(request_id, result)
    when "prompts/list"
      result = handle_prompts_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "prompts/get"
      result = handle_prompts_get(request, account)
      JSON::RPC::Response.new(request_id, result)
    end
  end

  private def self.handle_notification(request : JSON::RPC::Request)
    case request.method
    when "notifications/initialized"
      # no action needed without sessions
    when "notifications/cancelled"
      # no action needed without sessions
    else
      # ignore
    end
  end

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

    def MCPController.handle_tool_{{name.id}}(params : JSON::Any, account : Account) : JSON::Any
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

  private def self.handle_tools_list(request : JSON::RPC::Request) : JSON::Any
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

  private def self.handle_tools_call(request : JSON::RPC::Request, account : Account) : JSON::Any
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

  alias PromptArgumentDefinition =
    NamedTuple(
      name: String,
      title: String?,
      description: String?,
      required: Bool,
    )

  alias PromptDefinition =
    NamedTuple(
      name: String,
      title: String?,
      description: String?,
      arguments: Array(PromptArgumentDefinition),
    )

  PROMPT_DEFINITIONS = [] of PromptDefinition

  macro def_prompt(name, title = nil, description = nil, arguments = [] of PromptArgumentDefinition, &block)
    {% PROMPT_DEFINITIONS << {name: name, title: title, description: description, arguments: arguments} %}

    def MCPController.handle_prompt_{{name.id}}(arguments : JSON::Any, account : Account) : JSON::Any
      missing_fields = [] of String
      {% for arg in arguments %}
        {% if arg[:required] %}
          missing_fields << {{arg[:name]}} unless arguments[{{arg[:name]}}]?
        {% end %}
      {% end %}
      unless missing_fields.empty?
        raise MCPError.new("Missing #{missing_fields.join(", ")}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      {% for arg in arguments %}
        {{arg[:name].id}} =
          {% if arg[:required] %}
            arguments[{{arg[:name]}}].as_s
          {% else %}
            arguments[{{arg[:name]}}]?.try(&.as_s) || ""
          {% end %}
      {% end %}

      {% if block %}
        {{block.body}}
      {% else %}
        {% raise "`def_prompt` requires a block" %}
      {% end %}
    end
  end

  private def self.handle_prompts_list(request : JSON::RPC::Request) : JSON::Any
    prompts = [] of JSON::Any

    # built-in prompts
    {% for prompt in PROMPT_DEFINITIONS %}
      prompt_hash = {} of String => JSON::Any
      prompt_hash["name"] = JSON::Any.new({{prompt[:name]}})
      {% if prompt[:title] %}
        prompt_hash["title"] = JSON::Any.new({{prompt[:title]}})
      {% end %}
      {% if prompt[:description] %}
        prompt_hash["description"] = JSON::Any.new({{prompt[:description]}})
      {% end %}
      arguments = [] of JSON::Any
      {% for arg in prompt[:arguments] %}
        arg_hash = {} of String => JSON::Any
        arg_hash["name"] = JSON::Any.new({{arg[:name]}})
        {% if arg[:title] %}
          arg_hash["title"] = JSON::Any.new({{arg[:title]}})
        {% end %}
        {% if arg[:description] %}
          arg_hash["description"] = JSON::Any.new({{arg[:description]}})
        {% end %}
        arg_hash["required"] = JSON::Any.new({{arg[:required]}})
        arguments << JSON::Any.new(arg_hash)
      {% end %}
      prompt_hash["arguments"] = JSON::Any.new(arguments)
      prompts << JSON::Any.new(prompt_hash)
    {% end %}

    # YAML prompts
    Prompt.all.each do |prompt|
      prompt_hash = {} of String => JSON::Any
      prompt_hash["name"] = JSON::Any.new(prompt.name)
      if title = prompt.title
        prompt_hash["title"] = JSON::Any.new(title)
      end
      if description = prompt.description
        prompt_hash["description"] = JSON::Any.new(description)
      end
      arguments = [] of JSON::Any
      prompt.arguments.each do |arg|
        arg_hash = {} of String => JSON::Any
        arg_hash["name"] = JSON::Any.new(arg.name)
        if title = arg.title
          arg_hash["title"] = JSON::Any.new(title)
        end
        if description = arg.description
          arg_hash["description"] = JSON::Any.new(description)
        end
        arg_hash["required"] = JSON::Any.new(arg.required)
        arguments << JSON::Any.new(arg_hash)
      end
      prompt_hash["arguments"] = JSON::Any.new(arguments)
      prompts << JSON::Any.new(prompt_hash)
    end

    JSON::Any.new({
      "prompts" => JSON::Any.new(prompts)
    })
  end

  private def self.handle_prompts_get(request : JSON::RPC::Request, account : Account) : JSON::Any
    unless (params = request.params)
      raise MCPError.new("Missing params", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
    unless (name = params["name"]?.try(&.as_s))
      raise MCPError.new("Missing prompt name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    Log.debug { "getting prompt: #{name}" }

    # built-in prompts
    {% for prompt in PROMPT_DEFINITIONS %}
      if name == {{prompt[:name]}}
        return handle_prompt_{{prompt[:name].id}}(params, account)
      end
    {% end %}

    # YAML prompts
    if (prompt = Prompt.find?(name))
      return handle_prompt(prompt, params, account)
    end

    Log.warn { "unknown prompt: #{name}" }
    raise MCPError.new("Invalid prompt name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
  end

  private def self.handle_prompt(prompt : Prompt, params : JSON::Any, account : Account) : JSON::Any
    arguments = {} of String => String
    if (args = params["arguments"]?)
      if args_hash = args.as_h?
        args_hash.each do |key, value|
          arguments[key] = value.as_s if value.as_s?
        end
      end
    end

    context = {
      "language" => account.language || "",
      "timezone" => account.timezone || "UTC",
      "host" => Ktistec.host,
      "site" => Ktistec.site,
    }

    messages = [] of JSON::Any

    prompt.messages.each do |message|
      message_hash = {} of String => JSON::Any
      message_hash["role"] = JSON::Any.new(message.role.to_s.downcase)

      content_hash = {} of String => JSON::Any
      content_hash["type"] = JSON::Any.new(message.content.type.to_s.downcase)

      if text = message.content.text
        processed_text = Prompt.substitute(text, arguments, context)
        content_hash["text"] = JSON::Any.new(processed_text)
      end

      if data = message.content.data
        content_hash["data"] = JSON::Any.new(data)
      end

      if mime_type = message.content.mime_type
        content_hash["mimeType"] = JSON::Any.new(mime_type)
      end

      message_hash["content"] = JSON::Any.new(content_hash)
      messages << JSON::Any.new(message_hash)
    end

    JSON::Any.new({
      "messages" => JSON::Any.new(messages)
    })
  end

  private def self.notification_to_json_any(notification) : JSON::Any?
    case notification
    when Relationship::Content::Notification::Mention
      JSON::Any.new({
        "type" => JSON::Any.new("mention"),
        "object" => JSON::Any.new(mcp_object_path(notification.object)),
        "action_url" => JSON::Any.new("#{host}#{remote_object_path(notification.object)}"),
        "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
      })
    when Relationship::Content::Notification::Reply
      JSON::Any.new({
        "type" => JSON::Any.new("reply"),
        "object" => JSON::Any.new(mcp_object_path(notification.object)),
        "action_url" => JSON::Any.new("#{host}#{remote_object_path(notification.object)}"),
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
        "action_url" => JSON::Any.new("#{host}#{remote_actor_path(notification.activity.actor)}"),
        "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
      })
    when Relationship::Content::Notification::Like
      JSON::Any.new({
        "type" => JSON::Any.new("like"),
        "actor" => JSON::Any.new(mcp_actor_path(notification.activity.actor)),
        "object" => JSON::Any.new(mcp_object_path(notification.activity.object)),
        "action_url" => JSON::Any.new("#{host}#{remote_object_path(notification.activity.object)}"),
        "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
      })
    when Relationship::Content::Notification::Announce
      JSON::Any.new({
        "type" => JSON::Any.new("announce"),
        "actor" => JSON::Any.new(mcp_actor_path(notification.activity.actor)),
        "object" => JSON::Any.new(mcp_object_path(notification.activity.object)),
        "action_url" => JSON::Any.new("#{host}#{remote_object_path(notification.activity.object)}"),
        "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
      })
    when Relationship::Content::Notification::Follow::Hashtag
      JSON::Any.new({
        "type" => JSON::Any.new("follow_hashtag"),
        "hashtag" => JSON::Any.new(notification.name),
        "action_url" => JSON::Any.new("#{host}#{hashtag_path(notification.name)}"),
        "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
      })
    when Relationship::Content::Notification::Follow::Mention
      JSON::Any.new({
        "type" => JSON::Any.new("follow_mention"),
        "mention" => JSON::Any.new(notification.name),
        "action_url" => JSON::Any.new("#{host}#{mention_path(notification.name)}"),
        "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
      })
    when Relationship::Content::Notification::Follow::Thread
      JSON::Any.new({
        "type" => JSON::Any.new("follow_thread"),
        "thread" => JSON::Any.new(notification.object.thread),
        "action_url" => JSON::Any.new("#{host}#{remote_thread_path(notification.object, anchor: false)}"),
        "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
      })
    else
      nil
    end
  end

end
