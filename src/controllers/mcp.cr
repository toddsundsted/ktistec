require "../framework/controller"
require "../utils/json_rpc"
require "../models/account"
require "../models/activity_pub/object"

require "markd"

class MCPError < Exception
  getter code : Int32

  def initialize(@message : String, @code : Int32)
    super(@message)
  end
end

class MCPController
  include Ktistec::Controller

  Log = ::Log.for(self)

  skip_auth ["/mcp"], GET, POST

  get "/mcp" do |env|
    method_not_allowed ["POST"]
  end

  private macro mcp_response(status_code, response)
    env.response.content_type = "application/json"
    halt env, status_code: {{status_code}}, response: {{response}}.try(&.to_json)
  end

  post "/mcp" do |env|
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
        mcp_response 204, nil
      elsif (response = handle_request(request))
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
    JSON.parse(
      JSON.build do |json|
        json.object do
          json.field "protocolVersion", "2025-03-26"
          json.field "capabilities" do
            json.object do
              json.field "resources" do
                json.object {}
              end
              json.field "resourceTemplates" do
                json.object {}
              end
              json.field "tools" do
                json.object {}
              end
            end
          end
          json.field "serverInfo" do
            json.object do
              json.field "name", "Ktistec MCP Server"
              json.field "version", "1.0.0"
            end
          end
          json.field "instructions", "Provides access to ActivityPub actors, objects, and collections"
        end
      end
    )
  end

  private def self.handle_request(request : JSON::RPC::Request) : JSON::RPC::Response?
    request_id = request.id.not_nil!
    Log.debug { "dispatching: method=#{request.method}" }

    case request.method
    when "initialize"
      result = handle_initialize(request)
      JSON::RPC::Response.new(request_id, result)
    when "resources/list"
      result = handle_resources_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "resources/read"
      result = handle_resources_read(request)
      JSON::RPC::Response.new(request_id, result)
    when "resources/templates/list"
      result = handle_resources_templates_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "tools/list"
      result = handle_tools_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "tools/call"
      result = handle_tools_call(request)
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

  private def self.handle_resources_list(request : JSON::RPC::Request) : JSON::Any
    resources =
      Account.all.map do |account|
        resource = {
          "uri" => JSON::Any.new("ktistec://users/#{account.id}"),
          "mimeType" => JSON::Any.new("application/json"),
          "name" => JSON::Any.new(account.username),
        }
        JSON::Any.new(resource)
      end
    JSON::Any.new({
      "resources" => JSON::Any.new(resources)
    })
  end

  private def self.handle_resources_templates_list(request : JSON::RPC::Request) : JSON::Any
    templates = [
      JSON::Any.new({
        "uriTemplate" => JSON::Any.new("ktistec://objects/{id}"),
        "mimeType" => JSON::Any.new("application/json"),
        "name" => JSON::Any.new("Object"),
        "description" => JSON::Any.new("ActivityPub objects"),
      })
    ]
    JSON::Any.new({
      "resourceTemplates" => JSON::Any.new(templates)
    })
  end

  private def self.process_object_content(object : ActivityPub::Object) : Hash(String, JSON::Any)
    translation = object.translations.first?
    name = translation.try(&.name).presence || object.name.presence
    summary = translation.try(&.summary).presence || object.summary.presence
    content = translation.try(&.content).presence || object.content.presence

    if content && object.media_type == "text/markdown"
      content = Markd.to_html(content)
    end

    # process attachments to filter out embedded image URLs
    embedded_urls = [] of String
    if content && (attachments = object.attachments)
      begin
        html_doc = XML.parse_html(content)
        embedded_urls = html_doc.xpath_nodes("//img/@src").map(&.text)
      rescue
        # continue without filtering attachments
      end
    end
    filtered_attachments = object.attachments.try(&.reject { |a| a.url.in?(embedded_urls) })

    result = Hash(String, JSON::Any).new
    result["uri"] = JSON::Any.new("ktistec://objects/#{object.id}")

    if name
      result["name"] = JSON::Any.new(name)
    end
    if summary
      result["summary"] = JSON::Any.new(summary)
    end
    if content
      result["content"] = JSON::Any.new(content)
    end
    if object.media_type
      result["media_type"] = JSON::Any.new(object.media_type)
    end
    if object.language
      result["language"] = JSON::Any.new(object.language)
    end

    if filtered_attachments && !filtered_attachments.empty?
      attachment_data = filtered_attachments.map do |attachment|
        JSON::Any.new({
          "url" => JSON::Any.new(attachment.url),
          "media_type" => JSON::Any.new(attachment.media_type),
          "caption" => JSON::Any.new(attachment.caption || "")
        })
      end
      result["attachments"] = JSON::Any.new(attachment_data)
    end

    if translation
      result["is_translated"] = JSON::Any.new(true)
      result["original_language"] = JSON::Any.new(object.language || "")
    end

    result
  end

  private def self.handle_resources_read(request : JSON::RPC::Request) : JSON::Any
    unless (params = request.params)
      raise MCPError.new("Missing params", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
    unless (uri = params["uri"]?.try(&.as_s))
      raise MCPError.new("Missing URI parameter", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    if uri =~ /^ktistec:\/\/users\/(\d+)$/
      unless (account_id = $1.to_i64?)
        raise MCPError.new("Invalid user ID in URI: #{$1}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
      unless (account = Account.find?(account_id))
        raise MCPError.new("User not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      user_data = {
        "uri" => JSON::Any.new(uri),
        "mimeType" => JSON::Any.new("application/json"),
        "name" => JSON::Any.new(account.username),
      }

      actor = account.actor
      text_data = {} of String => JSON::Any
      if (name = actor.name)
        text_data["name"] = JSON::Any.new(name)
      end
      if (summary = actor.summary)
        text_data["summary"] = JSON::Any.new(summary)
      end
      if (icon = actor.icon)
        text_data["icon"] = JSON::Any.new(icon)
      end
      if (image = actor.image)
        text_data["image"] = JSON::Any.new(image)
      end
      if (attachments = actor.attachments.presence)
        text_data["attachments"] = JSON::Any.new(attachments.map { |a| JSON.parse(a.to_json) })
      end
      if (urls = actor.urls.presence)
        text_data["urls"] = JSON::Any.new(urls.map { |u| JSON::Any.new(u) })
      end
      user_data["text"] = JSON::Any.new(text_data.to_json)

      JSON::Any.new({
        "contents" => JSON::Any.new([
          JSON::Any.new(user_data)
        ])
      })

    elsif uri =~ /^ktistec:\/\/objects\/(\d+)$/
      unless (object_id = $1.to_i64?)
        raise MCPError.new("Invalid object ID in URI: #{$1}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
      unless (object = ActivityPub::Object.find?(object_id))
        raise MCPError.new("Object not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      text_data = process_object_content(object)

      object_data = {
        "uri" => JSON::Any.new(uri),
        "mimeType" => JSON::Any.new("application/json"),
        "name" => JSON::Any.new(object.name || "Object #{object.id}"),
        "text" => JSON::Any.new(text_data.to_json)
      }

      JSON::Any.new({
        "contents" => JSON::Any.new([
          JSON::Any.new(object_data)
        ])
      })

    else
      raise MCPError.new("Unsupported URI scheme: #{uri}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
  end

  private def self.handle_tools_list(request : JSON::RPC::Request) : JSON::Any
    tools = [
      JSON::Any.new({
        "name" => JSON::Any.new("paginate_collection"),
        "description" => JSON::Any.new("Paginate through collections of objects, activities, and actors"),
        "inputSchema" => JSON::Any.new({
          "type" => JSON::Any.new("object"),
          "properties" => JSON::Any.new({
            "user" => JSON::Any.new({
              "type" => JSON::Any.new("string"),
              "description" => JSON::Any.new("URI of the user whose collections to paginate")
            }),
            "name" => JSON::Any.new({
              "type" => JSON::Any.new("string"),
              "description" => JSON::Any.new("Name of the collection to paginate")
            }),
            "page" => JSON::Any.new({
              "type" => JSON::Any.new("integer"),
              "description" => JSON::Any.new("Page number (optional, defaults to 1)"),
              "minimum" => JSON::Any.new(1)
            }),
            "size" => JSON::Any.new({
              "type" => JSON::Any.new("integer"),
              "description" => JSON::Any.new("Number of items per page (optional, defaults to 10, maximum 1000)"),
              "minimum" => JSON::Any.new(1),
              "maximum" => JSON::Any.new(20)
            }),
          }),
          "required" => JSON::Any.new([JSON::Any.new("user"), JSON::Any.new("name")])
        })
      }),
      JSON::Any.new({
        "name" => JSON::Any.new("count_collection_since"),
        "description" => JSON::Any.new("Count items in collections since a given time"),
        "inputSchema" => JSON::Any.new({
          "type" => JSON::Any.new("object"),
          "properties" => JSON::Any.new({
            "user" => JSON::Any.new({
              "type" => JSON::Any.new("string"),
              "description" => JSON::Any.new("URI of the user whose collection to count")
            }),
            "name" => JSON::Any.new({
              "type" => JSON::Any.new("string"),
              "description" => JSON::Any.new("Name of the collection to count")
            }),
            "since" => JSON::Any.new({
              "type" => JSON::Any.new("string"),
              "description" => JSON::Any.new("ISO8601 time to count from")
            })
          }),
          "required" => JSON::Any.new([JSON::Any.new("user"), JSON::Any.new("name"), JSON::Any.new("since")])
        })
      })
    ]

    JSON::Any.new({
      "tools" => JSON::Any.new(tools)
    })
  end

  private def self.handle_tools_call(request : JSON::RPC::Request) : JSON::Any
    unless (params = request.params)
      raise MCPError.new("Missing params", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
    unless (name = params["name"]?.try(&.as_s))
      raise MCPError.new("Missing tool name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    Log.debug { "calling tool: #{name}" }

    case name
    when "paginate_collection"
      handle_paginate_collection_tool(params)
    when "count_collection_since"
      handle_count_collection_since_tool(params)
    else
      Log.warn { "unknown tool: #{name}" }
      raise MCPError.new("Invalid tool name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
  end

  private def self.handle_paginate_collection_tool(params : JSON::Any) : JSON::Any
    unless (arguments = params["arguments"]?)
      raise MCPError.new("Missing arguments", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    missing_fields = [] of String
    missing_fields << "user URI" unless arguments["user"]?.try(&.as_s)
    missing_fields << "collection name" unless arguments["name"]?.try(&.as_s)
    unless missing_fields.empty?
      raise MCPError.new("Missing #{missing_fields.join(", ")}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    user = arguments["user"].as_s
    name = arguments["name"].as_s

    page = arguments["page"]?.try(&.as_i) || 1
    if page < 1
      raise MCPError.new("Page must be >= 1", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    size = arguments["size"]?.try(&.as_i) || 10
    if size < 1
      raise MCPError.new("Size must be >= 1", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
    if size > 20
      raise MCPError.new("Size cannot exceed 20", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    unless user.starts_with?("ktistec://users/")
      raise MCPError.new("Invalid user URI format", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
    unless (user_id = user.sub("ktistec://users/", "").to_i64?)
      raise MCPError.new("Invalid user ID in URI", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
    unless (account = Account.find?(user_id))
      raise MCPError.new("User not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    Log.debug { "paginate_collection: user=#{user} collection=#{name} page=#{page} size=#{size}" }

    case name
    when "timeline"
      actor = account.actor
      timeline = actor.timeline(page: page, size: size)

      objects = timeline.map do |rel|
        JSON::Any.new("ktistec://objects/#{rel.object.id}")
      end

      result_data = {
        "objects" => objects.to_a,
        "more" => timeline.more?
      }

      JSON::Any.new({
        "content" => JSON::Any.new([JSON::Any.new({
          "type" => JSON::Any.new("text"),
          "text" => JSON::Any.new(result_data.to_json)
        })])
      })
    else
      raise MCPError.new("Invalid collection name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
  end

  private def self.handle_count_collection_since_tool(params : JSON::Any) : JSON::Any
    unless (arguments = params["arguments"]?)
      raise MCPError.new("Missing arguments", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    missing_fields = [] of String
    missing_fields << "user URI" unless arguments["user"]?.try(&.as_s)
    missing_fields << "collection name" unless arguments["name"]?.try(&.as_s)
    missing_fields << "since timestamp" unless arguments["since"]?.try(&.as_s)
    unless missing_fields.empty?
      raise MCPError.new("Missing #{missing_fields.join(", ")}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    user = arguments["user"].as_s
    name = arguments["name"].as_s
    since = arguments["since"].as_s

    begin
      time = Time.parse_rfc3339(since)
    rescue
      raise MCPError.new("Invalid timestamp format", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    unless user.starts_with?("ktistec://users/")
      raise MCPError.new("Invalid user URI format", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
    unless (user_id = user.sub("ktistec://users/", "").to_i64?)
      raise MCPError.new("Invalid user ID in URI", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
    unless (account = Account.find?(user_id))
      raise MCPError.new("User not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    Log.debug { "count_collection_since: user=#{user} collection=#{name} since=#{since}" }

    case name
    when "timeline"
      actor = account.actor
      current_time = Time.utc
      count = actor.timeline(since: time)

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
    else
      raise MCPError.new("Invalid collection name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
  end
end
