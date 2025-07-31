require "../framework/controller"
require "../utils/json_rpc"
require "../models/account"
require "../models/activity_pub/object"
require "../models/relationship/social/follow"
require "../models/tag/hashtag"
require "../models/tag/mention"
require "../models/oauth2/provider/access_token"

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

  get "/mcp" do |env|
    unauthorized unless authenticate_request(env)

    method_not_allowed ["POST"]
  end

  post "/mcp" do |env|
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
        mcp_response 204, nil
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
        "This server provides access to ActivityPub objects, activities, actors, and collections " \
        "in a Ktistec instance. Use resources to read user profiles and posts. Use tools to paginate " \
        "through collections (like timelines) and count new items since specific times. This is " \
        "particularly useful for monitoring ActivityPub feeds, tracking new content, and analyzing " \
        "social media activity patterns. The server supports both local and federated ActivityPub " \
        "content, with automatic translation support, and rich media attachment handling. For more " \
        "information about the server read the ktistec://information resource."
      ),
      "capabilities" => JSON::Any.new({
        "resources" => JSON::Any.new({} of String => JSON::Any),
        "resourceTemplates" => JSON::Any.new({} of String => JSON::Any),
        "tools" => JSON::Any.new({} of String => JSON::Any)
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
      result = handle_resources_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "resources/read"
      result = handle_resources_read(request, account)
      JSON::RPC::Response.new(request_id, result)
    when "resources/templates/list"
      result = handle_resources_templates_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "tools/list"
      result = handle_tools_list(request)
      JSON::RPC::Response.new(request_id, result)
    when "tools/call"
      result = handle_tools_call(request, account)
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
    resources = [] of JSON::Any

    resources << JSON::Any.new({
      "uri" => JSON::Any.new("ktistec://information"),
      "mimeType" => JSON::Any.new("application/json"),
      "name" => JSON::Any.new("Instance Information"),
    })

    Account.all.each do |account|
      resources << JSON::Any.new({
        "uri" => JSON::Any.new("ktistec://users/#{account.id}"),
        "mimeType" => JSON::Any.new("application/json"),
        "name" => JSON::Any.new(account.username),
      })
    end

    JSON::Any.new({
      "resources" => JSON::Any.new(resources)
    })
  end

  private def self.handle_resources_templates_list(request : JSON::RPC::Request) : JSON::Any
    templates = [
      JSON::Any.new({
        "uriTemplate" => JSON::Any.new("ktistec://actors/{id}"),
        "mimeType" => JSON::Any.new("application/json"),
        "name" => JSON::Any.new("Actor"),
        "description" => JSON::Any.new("ActivityPub actors"),
      }),
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

  private def self.instance_information(account : Account) : Hash(String, JSON::Any)
    contents = Hash(String, JSON::Any).new

    # basic instance information
    contents["version"] = JSON::Any.new(Ktistec::VERSION)
    contents["host"] = JSON::Any.new(Ktistec.host)
    contents["description"] = JSON::Any.new("Ktistec ActivityPub Server Model Context Protocol (MCP) Interface")

    # authenticated user information
    contents["authenticated_user"] = JSON::Any.new({
      "uri" => JSON::Any.new("ktistec://users/#{account.id}"),
      "username" => JSON::Any.new(account.username),
      "language" => JSON::Any.new(account.language || ""),
      "timezone" => JSON::Any.new(account.timezone)
    })

    # supported collections
    collections = [
      "posts", "drafts",
      "timeline", "notifications",
      "likes", "announcements",
      "followers", "following",
    ]
    contents["collections"] = JSON::Any.new(collections.map { |c| JSON::Any.new(c) })

    # supported collection formats
    collection_formats = {
      "hashtag" => %q(hashtag#{name}),
      "mention" => %q(mention@{name})
    }
    contents["collection_formats"] = JSON::Any.new(
      collection_formats.transform_values { |v| JSON::Any.new(v) }
    )

    # supported object types
    object_types = ActivityPub::Object.all_subtypes.map(&.split("::").last)
    contents["object_types"] = JSON::Any.new(object_types.map { |t| JSON::Any.new(t) })

    # supported actor types
    actor_types = ActivityPub::Actor.all_subtypes.map(&.split("::").last)
    contents["actor_types"] = JSON::Any.new(actor_types.map { |t| JSON::Any.new(t) })

    # statistics
    contents["statistics"] = JSON::Any.new({
      "total_users" => JSON::Any.new(Account.all.size.to_i64),
      "total_actors" => JSON::Any.new(ActivityPub::Actor.all.size.to_i64),
      "total_objects" => JSON::Any.new(ActivityPub::Object.all.size.to_i64)
    })

    contents
  end

  private def self.actor_contents(actor : ActivityPub::Actor) : Hash(String, JSON::Any)
    contents = Hash(String, JSON::Any).new

    contents["uri"] = JSON::Any.new("ktistec://actors/#{actor.id}")
    contents["external_url"] = JSON::Any.new(actor.iri)
    contents["internal_url"] = JSON::Any.new("#{Ktistec.host}/remote/actors/#{actor.id}")
    if (name = actor.name)
      contents["name"] = JSON::Any.new(name)
    end
    if (summary = actor.summary)
      contents["summary"] = JSON::Any.new(summary)
    end
    if (icon = actor.icon)
      contents["icon"] = JSON::Any.new(icon)
    end
    if (image = actor.image)
      contents["image"] = JSON::Any.new(image)
    end
    if (attachments = actor.attachments.presence)
      contents["attachments"] = JSON::Any.new(attachments.map { |a| attachment_to_json_any(a) })
    end
    if (urls = actor.urls.presence)
      contents["urls"] = JSON::Any.new(urls.map { |u| JSON::Any.new(u) })
    end
    contents["type"] = JSON::Any.new(actor.class.to_s.split("::").last)

    contents
  end

  private def self.object_contents(object : ActivityPub::Object) : Hash(String, JSON::Any)
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

    contents = Hash(String, JSON::Any).new

    contents["uri"] = JSON::Any.new("ktistec://objects/#{object.id}")
    contents["external_url"] = JSON::Any.new(object.iri)
    contents["internal_url"] = JSON::Any.new("#{Ktistec.host}/remote/objects/#{object.id}")
    if name
      contents["name"] = JSON::Any.new(name)
    end
    if summary
      contents["summary"] = JSON::Any.new(summary)
    end
    if content
      contents["content"] = JSON::Any.new(content)
    end
    if object.media_type
      contents["media_type"] = JSON::Any.new(object.media_type)
    end
    if object.language
      contents["language"] = JSON::Any.new(object.language)
    end
    if (published = object.published)
      contents["published"] = JSON::Any.new(published.to_rfc3339)
    end
    if (attributed_to = object.attributed_to?)
      contents["attributed_to"] = JSON::Any.new("ktistec://actors/#{attributed_to.id}")
    end
    if (in_reply_to = object.in_reply_to?)
      contents["in_reply_to"] = JSON::Any.new("ktistec://objects/#{in_reply_to.id}")
    end
    contents["type"] = JSON::Any.new(object.class.to_s.split("::").last)

    if filtered_attachments && !filtered_attachments.empty?
      attachment_data = filtered_attachments.map do |attachment|
        JSON::Any.new({
          "url" => JSON::Any.new(attachment.url),
          "media_type" => JSON::Any.new(attachment.media_type),
          "caption" => JSON::Any.new(attachment.caption || "")
        })
      end
      contents["attachments"] = JSON::Any.new(attachment_data)
    end

    if translation
      contents["is_translated"] = JSON::Any.new(true)
      contents["original_language"] = JSON::Any.new(object.language || "")
    end

    likes = ActivityPub::Activity::Like.where(object_iri: object.iri).to_a
    if likes.any?
      actors_data = likes.map do |like|
        JSON::Any.new({"uri" => JSON::Any.new("ktistec://actors/#{like.actor.id}")})
      end
      contents["likes"] = JSON::Any.new({
        "count" => JSON::Any.new(likes.size.to_i64),
        "actors" => JSON::Any.new(actors_data)
      })
    end

    announces = ActivityPub::Activity::Announce.where(object_iri: object.iri).to_a
    if announces.any?
      actors_data = announces.map do |announce|
        JSON::Any.new({"uri" => JSON::Any.new("ktistec://actors/#{announce.actor.id}")})
      end
      contents["announcements"] = JSON::Any.new({
        "count" => JSON::Any.new(announces.size.to_i64),
        "actors" => JSON::Any.new(actors_data)
      })
    end

    replies = object.replies(for_actor: nil) # `for_actor` is a dummy parameter
    if replies.any?
      objects_data = replies.map do |reply|
        reply_data = {
          "uri" => JSON::Any.new("ktistec://objects/#{reply.id}"),
          "author" => JSON::Any.new("ktistec://actors/#{reply.attributed_to.id}")
        }
        if (published = reply.published)
          reply_data["published"] = JSON::Any.new(published.to_rfc3339)
        end
        if (content = reply.content.presence)
          preview = Ktistec::Util.render_as_text(content)
          if preview.size > 100
            preview = preview[0...100].rstrip + "..."
          end
          if (preview = preview.presence)
            reply_data["preview"] = JSON::Any.new(preview)
          end
        end
        JSON::Any.new(reply_data)
      end
      contents["replies"] = JSON::Any.new({
        "count" => JSON::Any.new(replies.size.to_i64),
        "objects" => JSON::Any.new(objects_data)
      })
    end

    contents
  end

  private def self.handle_resources_read(request : JSON::RPC::Request, account : Account) : JSON::Any
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
      unless account.id == account_id
        raise MCPError.new("Access denied to user", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
      unless account.reload!
        raise MCPError.new("User not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      actor = account.actor
      text_data = actor_contents(actor)

      user_data = {
        "uri" => JSON::Any.new(uri),
        "mimeType" => JSON::Any.new("application/json"),
        "name" => JSON::Any.new(account.username),
        "text" => JSON::Any.new(text_data.to_json)
      }

      JSON::Any.new({
        "contents" => JSON::Any.new([
          JSON::Any.new(user_data)
        ])
      })

    elsif uri =~ /^ktistec:\/\/actors\/(\d+)$/
      unless (actor_id = $1.to_i64?)
        raise MCPError.new("Invalid actor ID in URI: #{$1}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
      unless (actor = ActivityPub::Actor.find?(actor_id))
        raise MCPError.new("Actor not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      text_data = actor_contents(actor)

      actor_data = {
        "uri" => JSON::Any.new(uri),
        "mimeType" => JSON::Any.new("application/json"),
        "name" => JSON::Any.new(actor.name || "Actor #{actor.id}"),
        "text" => JSON::Any.new(text_data.to_json)
      }

      JSON::Any.new({
        "contents" => JSON::Any.new([
          JSON::Any.new(actor_data)
        ])
      })

    elsif uri =~ /^ktistec:\/\/objects\/(\d+)$/
      unless (object_id = $1.to_i64?)
        raise MCPError.new("Invalid object ID in URI: #{$1}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end
      unless (object = ActivityPub::Object.find?(object_id))
        raise MCPError.new("Object not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      end

      text_data = object_contents(object)

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

    elsif uri == "ktistec://information"
      text_data = instance_information(account)

      information_data = {
        "uri" => JSON::Any.new(uri),
        "mimeType" => JSON::Any.new("application/json"),
        "name" => JSON::Any.new("Instance Information"),
        "text" => JSON::Any.new(text_data.to_json)
      }

      JSON::Any.new({
        "contents" => JSON::Any.new([
          JSON::Any.new(information_data)
        ])
      })

    else
      raise MCPError.new("Unsupported URI scheme: #{uri}", JSON::RPC::ErrorCodes::INVALID_PARAMS)
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
      default: String | Int32 | Bool | Time | Nil,
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

    def MCPController.handle_{{name.id}}(params : JSON::Any, account : Account)
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
              raise MCPError.new("`#{{{prop[:name]}}}` must be a time format string", JSON::RPC::ErrorCodes::INVALID_PARAMS)
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
              raise MCPError.new("`#{{{prop[:name]}}}` must be a valid RFC3339 timestamp", JSON::RPC::ErrorCodes::INVALID_PARAMS)
            end
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

  def_tool("paginate_collection", "Paginate through collections of ActivityPub objects, activities, and actors. Use this tool when you want to inspect the contents of a collection.", [
    {name: "name", type: "string", description: "Name of the collection to paginate", required: true, matches: NAME_REGEX},
    {name: "page", type: "integer", description: "Page number (optional, defaults to 1)", minimum: 1, default: 1},
    {name: "size", type: "integer", description: "Number of items per page (optional, defaults to 10, maximum 1000)", minimum: 1, maximum: 20, default: 10},
  ]) do
    unless account.reload!
      raise MCPError.new("Account not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    Log.debug { "paginate_collection: user=ktistec://users/#{account.id} collection=#{name} page=#{page} size=#{size}" }

    actor = account.actor

    objects, more =
      case name
      when "notifications"
        notifications = actor.notifications(page: page, size: size)
        objects = notifications.map do |notification|
          case notification
          when Relationship::Content::Notification::Mention
            JSON::Any.new({
              "type" => JSON::Any.new("mention"),
              "object" => JSON::Any.new("ktistec://objects/#{notification.object.id}"),
              "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
            })
          when Relationship::Content::Notification::Reply
            JSON::Any.new({
              "type" => JSON::Any.new("reply"),
              "object" => JSON::Any.new("ktistec://objects/#{notification.object.id}"),
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
              "actor" => JSON::Any.new("ktistec://actors/#{notification.activity.actor.id}"),
              "object" => JSON::Any.new("ktistec://users/#{notification.owner.id}"),
              "created_at" => JSON::Any.new(notification.created_at.to_rfc3339),
            })
          else
            next
          end
        end
        {objects.compact, notifications.more?}
      when "timeline"
        timeline = actor.timeline(page: page, size: size)
        objects = timeline.map do |rel|
          JSON::Any.new("ktistec://objects/#{rel.object.id}")
        end
        {objects, timeline.more?}
      when "posts"
        posts = actor.all_posts(page: page, size: size)
        objects = posts.map do |post|
          JSON::Any.new("ktistec://objects/#{post.id}")
        end
        {objects, posts.more?}
      when "drafts"
        drafts = actor.drafts(page: page, size: size)
        objects = drafts.map do |draft|
          JSON::Any.new("ktistec://objects/#{draft.id}")
        end
        {objects, drafts.more?}
      when "likes"
        likes = actor.likes(page: page, size: size)
        objects = likes.map do |liked_object|
          JSON::Any.new("ktistec://objects/#{liked_object.id}")
        end
        {objects, likes.more?}
      when "announcements"
        announcements = actor.announces(page: page, size: size)
        objects = announcements.map do |announced_object|
          JSON::Any.new("ktistec://objects/#{announced_object.id}")
        end
        {objects, announcements.more?}
      when "followers"
        followers = Relationship::Social::Follow.followers_for(actor.iri, page: page, size: size)
        objects = followers.map do |relationship|
          JSON::Any.new({
            "actor" => JSON::Any.new("ktistec://actors/#{relationship.actor.id}"),
            "confirmed" => JSON::Any.new(relationship.confirmed)
          })
        end
        {objects, followers.more?}
      when "following"
        following = Relationship::Social::Follow.following_for(actor.iri, page: page, size: size)
        objects = following.map do |relationship|
          JSON::Any.new({
            "actor" => JSON::Any.new("ktistec://actors/#{relationship.object.id}"),
            "confirmed" => JSON::Any.new(relationship.confirmed)
          })
        end
        {objects, following.more?}
      else
        if name.starts_with?("hashtag#")
          hashtag = name.sub("hashtag#", "")
          unless Tag::Hashtag.most_recent_object(hashtag)
            raise MCPError.new("Hashtag '#{hashtag}' not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
          end
          hashtag_objects = Tag::Hashtag.all_objects(hashtag, page: page, size: size)
          objects = hashtag_objects.map do |obj|
            JSON::Any.new("ktistec://objects/#{obj.id}")
          end
          {objects, hashtag_objects.more?}
        elsif name.starts_with?("mention@")
          mention = name.sub("mention@", "")
          unless Tag::Mention.most_recent_object(mention)
            raise MCPError.new("Mention '#{mention}' not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
          end
          mention_objects = Tag::Mention.all_objects(mention, page: page, size: size)
          objects = mention_objects.map do |obj|
            JSON::Any.new("ktistec://objects/#{obj.id}")
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

  def_tool("count_collection_since", "Count items in ActivityPub collections since a given time. Use this tool when you want to know if new items have been added in the last day/week/month.", [
    {name: "name", type: "string", description: "Name of the collection to count", required: true, matches: NAME_REGEX},
    {name: "since", type: "time", description: "Time (RFC3339) to count from", required: true},
  ]) do
    unless account.reload!
      raise MCPError.new("Account not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    Log.debug { "count_collection_since: user=ktistec://users/#{account.id} collection=#{name} since=#{since}" }

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
        raise MCPError.new("Counting not supported for likes collection", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      when "announcements"
        raise MCPError.new("Counting not supported for announcements collections", JSON::RPC::ErrorCodes::INVALID_PARAMS)
      when "followers"
        Relationship::Social::Follow.followers_since(actor.iri, since)
      when "following"
        Relationship::Social::Follow.following_since(actor.iri, since)
      else
        if name.starts_with?("hashtag#")
          hashtag = name.sub("hashtag#", "")
          unless Tag::Hashtag.most_recent_object(hashtag)
            raise MCPError.new("Hashtag '#{hashtag}' not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
          end
          raise MCPError.new("Counting not supported for hashtag collections", JSON::RPC::ErrorCodes::INVALID_PARAMS)
        elsif name.starts_with?("mention@")
          mention = name.sub("mention@", "")
          unless Tag::Mention.most_recent_object(mention)
            raise MCPError.new("Mention '#{mention}' not found", JSON::RPC::ErrorCodes::INVALID_PARAMS)
          end
          raise MCPError.new("Counting not supported for mention collections", JSON::RPC::ErrorCodes::INVALID_PARAMS)
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
      handle_paginate_collection(params, account)
    when "count_collection_since"
      handle_count_collection_since(params, account)
    else
      Log.warn { "unknown tool: #{name}" }
      raise MCPError.new("Invalid tool name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end
  end

  private def self.attachment_to_json_any(attachment : ActivityPub::Actor::Attachment) : JSON::Any
    JSON::Any.new({
      "name" => JSON::Any.new(attachment.name),
      "value" => JSON::Any.new(attachment.value)
    })
  end
end
