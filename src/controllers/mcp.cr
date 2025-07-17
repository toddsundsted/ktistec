require "../framework/controller"
require "../utils/json_rpc"

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
            json.object {}
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
end
