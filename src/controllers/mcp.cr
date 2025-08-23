require "../framework/controller"
require "../models/account"
require "../models/oauth2/provider/access_token"
require "../utils/json_rpc"
require "../mcp/errors"
require "../mcp/resources"
require "../mcp/tools"
require "../mcp/prompts"

class MCPController
  include Ktistec::Controller

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
      result = MCP::Tools.handle_tools_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "tools/call"
      result = MCP::Tools.handle_tools_call(request, account)
      JSON::RPC::Response.new(request_id, result)
    when "prompts/list"
      result = MCP::Prompts.handle_prompts_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "prompts/get"
      result = MCP::Prompts.handle_prompts_get(request, account)
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
