require "file_utils"

require "../../src/controllers/mcp"

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
      "Content-Type"  => "application/json",
      "Accept"        => "application/json",
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
      make_env("POST", "/mcp").tap do |env|
        env.request.headers["Authorization"] = "Bearer oauth_token_123"
      end
    end

    it "returns account" do
      result = described_class.authenticate_request(env)
      expect(result).to eq(account)
    end

    context "authorization header is missing" do
      let(env) { make_env("POST", "/mcp") }

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
  end
end
