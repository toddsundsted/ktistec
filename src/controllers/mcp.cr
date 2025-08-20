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
require "../mcp/errors"
require "../mcp/resources"
require "../mcp/tools"

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
      result = MCP::Tools.handle_tools_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "tools/call"
      result = MCP::Tools.handle_tools_call(request, account)
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


end
