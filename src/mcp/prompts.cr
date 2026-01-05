require "./errors"
require "../utils/json_rpc"
require "../models/account"
require "../models/prompt"

module MCP
  module Prompts
    Log = ::Log.for("mcp")

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

      def MCP::Prompts.handle_prompt_{{name.id}}(arguments : JSON::Any, account : Account) : JSON::Any
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

    def self.handle_prompts_list(request : JSON::RPC::Request) : JSON::Any
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
        if (title = prompt.title)
          prompt_hash["title"] = JSON::Any.new(title)
        end
        if (description = prompt.description)
          prompt_hash["description"] = JSON::Any.new(description)
        end
        arguments = [] of JSON::Any
        prompt.arguments.each do |arg|
          arg_hash = {} of String => JSON::Any
          arg_hash["name"] = JSON::Any.new(arg.name)
          if (title = arg.title)
            arg_hash["title"] = JSON::Any.new(title)
          end
          if (description = arg.description)
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

    def self.handle_prompts_get(request : JSON::RPC::Request, account : Account) : JSON::Any
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
          return self.handle_prompt_{{prompt[:name].id}}(params, account)
        end
      {% end %}

      # YAML prompts
      if (prompt = Prompt.find?(name))
        return self.handle_prompt(prompt, params, account)
      end

      Log.warn { "unknown prompt: #{name}" }
      raise MCPError.new("Invalid prompt name", JSON::RPC::ErrorCodes::INVALID_PARAMS)
    end

    def self.handle_prompt(prompt : Prompt, params : JSON::Any, account : Account) : JSON::Any
      arguments = {} of String => String
      if (args = params["arguments"]?)
        if (args_hash = args.as_h?)
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

        if (text = message.content.text)
          processed_text = Prompt.substitute(text, arguments, context)
          content_hash["text"] = JSON::Any.new(processed_text)
        end

        if (data = message.content.data)
          content_hash["data"] = JSON::Any.new(data)
        end

        if (mime_type = message.content.mime_type)
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
end
