require "file_utils"

require "../../src/controllers/mcp"
require "../../src/models/activity_pub/actor/person"
require "../../src/models/oauth2/provider/access_token"
require "../../src/models/oauth2/provider/client"
require "../../src/models/relationship/content/notification/follow/thread"
require "../../src/models/relationship/content/notification/follow/hashtag"
require "../../src/models/relationship/content/notification/follow/mention"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe MCPController do
  setup_spec

  let(account) { register }

  let_create!(
    oauth2_provider_client,
    named: client,
  )
  let_create!(
    oauth2_provider_access_token,
    token: "oauth_token_123",
    account: account,
    client: client,
    expires_at: expires_at,
    scope: scope,
  )

  let(expires_at) { Time.utc + 1.hour }
  let(scope) { "mcp" }

  def authenticated_headers
    HTTP::Headers{
      "Authorization" => "Bearer oauth_token_123",
      "Content-Type" => "application/json",
      "Accept" => "application/json",
    }
  end

  describe ".protocol_version" do
    it "returns the client protocol version" do
      result = described_class.protocol_version("2025-03-26", ["2024-11-05", "2025-03-26", "2025-06-18"])
      expect(result).to eq("2025-03-26")
    end

    it "returns the latest protocol version the server supports" do
      result = described_class.protocol_version("2024-01-01", ["2024-11-05", "2025-03-26", "2025-06-18"])
      expect(result).to eq("2025-06-18")
    end
  end

  describe ".authenticate_request" do
    let(env) do
      env_factory("POST", "/mcp").tap do |env|
        env.request.headers["Authorization"] = "Bearer oauth_token_123"
      end
    end

    it "returns account" do
      result = described_class.authenticate_request(env)
      expect(result).to eq(account)
    end

    context "authorization header is missing" do
      let(env) { env_factory("POST", "/mcp") }

      it "returns nil" do
        result = described_class.authenticate_request(env)
        expect(result).to be_nil
      end
    end

    context "authorization header does not hold a bearer token" do
      let(env) { super.tap { |env| env.request.headers["Authorization"] = "Basic abc123" } }

      it "returns nil" do
        result = described_class.authenticate_request(env)
        expect(result).to be_nil
      end
    end

    context "access token does not include mcp scope" do
      let(scope) { "foobar" }

      it "returns nil" do
        result = described_class.authenticate_request(env)
        expect(result).to be_nil
      end
    end

    context "access token is expired" do
      let(expires_at) { Time.utc - 1.hour }

      it "returns nil" do
        result = described_class.authenticate_request(env)
        expect(result).to be_nil
      end
    end
  end

  def expect_mcp_error(code, message)
    expect(response.status_code).to eq(400)
    parsed = JSON.parse(response.body)
    expect(parsed["error"]["code"]).to eq(code)
    expect(parsed["error"]["message"]).to eq(message)
  end

  describe "GET /mcp" do
    it "returns method not allowed" do
      get "/mcp", authenticated_headers
      expect(response.status_code).to eq(405)
      expect(response.headers["Allow"]).to eq("POST")
      expect(response.content_type).to contain("application/json")
      expect(response.body).to match(/"method not allowed"/)
    end
  end

  describe "POST /mcp" do
    context "with MCP initialize request" do
      let(json) {
        %Q|
          {
            "jsonrpc": "2.0",
            "id": "init-1",
            "method": "initialize",
            "params": {
              "protocolVersion": "2025-03-26",
              "capabilities": {
                "roots": {"listChanged": true},
                "sampling": {}
              },
              "clientInfo": {
                "name": "TestClient",
                "version": "1.0.0"
              }
            }
          }
        |
      }

      it "returns proper MCP initialize response" do
        post "/mcp", authenticated_headers, json
        expect(response.status_code).to eq(200)

        parsed = JSON.parse(response.body)
        expect(parsed["jsonrpc"]).to eq("2.0")
        expect(parsed["id"]).to eq("init-1")

        result = parsed["result"]
        expect(result["protocolVersion"]).to eq("2025-03-26")
        expect(result["serverInfo"]["name"]).to eq("Ktistec MCP Server")
        expect(result["serverInfo"]["version"]).to eq(Ktistec::VERSION)
        expect(result["capabilities"]["resources"]).to be_a(JSON::Any)
        expect(result["capabilities"]["tools"]).to be_a(JSON::Any)
        expect(result["capabilities"]["prompts"]).to be_a(JSON::Any)
        expect(result["instructions"]).to be_a(JSON::Any)
      end
    end

    context "with invalid JSON" do
      let(json) { %Q|{"invalid": json}| }

      it "returns parse error" do
        post "/mcp", authenticated_headers, json
        expect(response.status_code).to eq(400)

        parsed = JSON.parse(response.body)
        expect(parsed["jsonrpc"]).to eq("2.0")
        expect(parsed["id"]).to eq("null")
        expect(parsed["error"]["code"]).to eq(-32700)
        expect(parsed["error"]["message"]).to eq("Parse error")
      end
    end

    context "with unknown method" do
      let(json) { %Q|{"jsonrpc": "2.0", "id": "unknown-1", "method": "unknown/method"}| }

      it "returns method not found error" do
        post "/mcp", authenticated_headers, json
        expect(response.status_code).to eq(404)
        parsed = JSON.parse(response.body)

        expect(parsed["jsonrpc"]).to eq("2.0")
        expect(parsed["id"]).to eq("unknown-1")
        expect(parsed["error"]["code"]).to eq(-32601)
        expect(parsed["error"]["message"].as_s).to contain("Method not found")
        expect(parsed["error"]["message"].as_s).to contain("unknown/method")
      end
    end

    context "with invalid content type" do
      it "returns 400" do
        post "/mcp", authenticated_headers.merge!({"Accept" => "text/html"}), "test"
        expect(response.status_code).to eq(400)
      end
    end

    MCPController.def_prompt("test_prompt", "Test Prompt", "A test prompt for `def_prompt` macro testing", [
      {name: "topic", title: "Topic", description: "The main topic to discuss", required: true},
      {name: "style", title: "Style", description: "Communication style", required: false},
    ]) do
      style_text = style.empty? ? "" : " in a #{style} style"
      JSON::Any.new([
        JSON::Any.new({
          "role" => JSON::Any.new("user"),
          "content" => JSON::Any.new({
            "type" => JSON::Any.new("text"),
            "text" => JSON::Any.new("Please discuss #{topic}#{style_text}.")
          })
        }),
        JSON::Any.new({
          "role" => JSON::Any.new("assistant"),
          "content" => JSON::Any.new({
            "type" => JSON::Any.new("text"),
            "text" => JSON::Any.new("The request cost is 0.01 KTs.")
          })
        }),
      ])
    end

    # override for testing
    class ::Prompt
      def self.reset!
        @@cached_prompts = [] of Prompt
        @@cache_timestamp = Time::UNIX_EPOCH
      end

      @@test_temp_dir = File.join(File.tempname, "mcp_prompts_test")

      # override private visibility and create temporary directory for testing
      def self.default_prompts_dir : String
        Dir.mkdir_p(@@test_temp_dir) unless Dir.exists?(@@test_temp_dir)
        @@test_temp_dir
      end
    end

    context "with prompts/list request" do
      let(prompts_list_request) { %Q|{"jsonrpc": "2.0", "id": "prompts-1", "method": "prompts/list"}| }

      before_each do
        Prompt.reset!

        # copy whats_new.yml for prompt testing
        in_file = File.join(Dir.current, "etc", "prompts", "whats_new.yml")
        out_file = File.join(Prompt.default_prompts_dir, "whats_new.yml")
        File.write(out_file, File.read(in_file))
      end

      after_each do
        FileUtils.rm_rf(Prompt.default_prompts_dir)
      end

      it "returns prompts" do
        post "/mcp", authenticated_headers, prompts_list_request
        expect(response.status_code).to eq(200)
        parsed = JSON.parse(response.body)

        prompts = parsed["result"]["prompts"].as_a
        expect(prompts.size).to eq(2)  # test_prompt & whats_new

        names = prompts.map { |p| p["name"].as_s }
        expect(names).to contain("test_prompt", "whats_new")
      end

      context "test_prompt" do
        let(test_prompt) do
          post "/mcp", authenticated_headers, prompts_list_request
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)
          prompts = parsed["result"]["prompts"].as_a
          prompts.find { |p| p["name"].as_s == "test_prompt" }.not_nil!
        end

        it "returns the definition" do
          expect(test_prompt["name"]).to eq("test_prompt")
          expect(test_prompt["title"]).to eq("Test Prompt")
          expect(test_prompt["description"]).to eq("A test prompt for `def_prompt` macro testing")

          arguments = test_prompt["arguments"].as_a
          expect(arguments.size).to eq(2)

          expect(arguments[0]["name"]).to eq("topic")
          expect(arguments[0]["title"]).to eq("Topic")
          expect(arguments[0]["description"]).to eq("The main topic to discuss")
          expect(arguments[0]["required"]).to be_true

          expect(arguments[1]["name"]).to eq("style")
          expect(arguments[1]["title"]).to eq("Style")
          expect(arguments[1]["description"]).to eq("Communication style")
          expect(arguments[1]["required"]).to be_false
        end
      end

      context "whats_new" do
        let(whats_new) do
          post "/mcp", authenticated_headers, prompts_list_request
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)
          prompts = parsed["result"]["prompts"].as_a
          prompts.find { |p| p["name"].as_s == "whats_new" }.not_nil!
        end

        it "returns the definition" do
          expect(whats_new["name"]).to eq("whats_new")
          expect(whats_new["title"]).to eq("What's New Social Media Activity Summary")
          expect(whats_new["description"]).to eq("Generate Ktistec social media activity summary with workflow instructions")

          arguments = whats_new["arguments"].as_a
          expect(arguments.size).to eq(0) # whats_new has no explicit arguments
        end
      end
    end

    context "test_prompt validation" do
      it "validates and extracts arguments" do
        arguments = JSON::Any.new({
          "topic" => JSON::Any.new("ActivityPub federation"),
          "style" => JSON::Any.new("technical"),
        })

        result = MCPController.handle_prompt_test_prompt(arguments, account)
        messages = result.as_a
        expect(messages.size).to eq(2)
        message = messages[0]
        expect(message["role"].as_s).to eq("user")
        content = message["content"]
        expect(content["type"].as_s).to eq("text")
        expect(content["text"].as_s).to eq("Please discuss ActivityPub federation in a technical style.")
        message = messages[1]
        expect(message["role"].as_s).to eq("assistant")
        content = message["content"]
        expect(content["type"].as_s).to eq("text")
        expect(content["text"].as_s).to eq("The request cost is 0.01 KTs.")
      end

      it "handles optional arguments" do
        arguments = JSON::Any.new({
          "topic" => JSON::Any.new("ActivityPub protocol"),
          # style parameter is optional
        })

        result = MCPController.handle_prompt_test_prompt(arguments, account)
        message = result.as_a[0]
        content = message["content"]
        expect(content["text"].as_s).to eq("Please discuss ActivityPub protocol.")
      end

      it "validates required arguments" do
        arguments = JSON::Any.new({} of String => JSON::Any)

        expect { MCPController.handle_prompt_test_prompt(arguments, account) }.to raise_error(MCPError, /Missing topic/)
      end
    end

    context "with prompts/get request" do
      let(prompts_get_request) { %Q|{"jsonrpc": "2.0", "id": "prompt-get-1", "method": "prompts/get", "params": {"name": "nonexistent_prompt"}}| }

      it "returns protocol error for invalid tool name" do
        post "/mcp", authenticated_headers, prompts_get_request
        expect_mcp_error(-32602, "Invalid prompt name")
      end
    end
  end
end
