require "../framework/controller"
require "../utils/json_rpc"
require "../models/account"

class MCPError < Exception
  getter code : Int32

  def initialize(@message : String, @code : Int32)
    super(@message)
  end
end

class McpController
  include Ktistec::Controller

  skip_auth ["/mcp"], POST

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

      if request.notification?
        handle_notification(request)
        mcp_response 204, nil
      elsif (response = handle_request(request))
        mcp_response 200, response
      else
        error = JSON::RPC::Response::Error.new(JSON::RPC::ErrorCodes::METHOD_NOT_FOUND, "Method not found: #{request.method}")
        error_response = JSON::RPC::Response.new(request.id.not_nil!, error: error)
        mcp_response 404, error_response
      end
    rescue JSON::ParseException
      error = JSON::RPC::Response::Error.new(JSON::RPC::ErrorCodes::PARSE_ERROR, "Parse error")
      error_response = JSON::RPC::Response.new("null", error: error)
      mcp_response 400, error_response
    rescue err : MCPError
      error = JSON::RPC::Response::Error.new(err.code, err.message || "Unknown error")
      error_response = JSON::RPC::Response.new(request.try(&.id) || "null", error: error)
      mcp_response 400, error_response
    rescue
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

  private def self.handle_resources_read(request : JSON::RPC::Request) : JSON::Any
    unless (params = request.params)
      raise MCPError.new("Missing params", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
    unless (uri = params["uri"]?.try(&.as_s))
      raise MCPError.new("Missing URI parameter", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    # parse ktistec://users/{id} format
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
    else
      raise MCPError.new("Unsupported URI scheme: #{uri}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
  end
end
