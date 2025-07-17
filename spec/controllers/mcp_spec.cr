require "../../src/controllers/mcp"

require "../spec_helper/factory"
require "../spec_helper/controller"

Spectator.describe McpController do
  setup_spec

  JSON_HEADERS = HTTP::Headers{"Accept" => "application/json", "Content-Type" => "application/json"}

  describe "POST /mcp" do
    it "accepts JSON-RPC requests" do
      post "/mcp", JSON_HEADERS, %Q|{"jsonrpc": "2.0", "id": 1, "method": "test"}|
      expect(response.status_code).to eq(404)
    end

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
        post "/mcp", JSON_HEADERS, json
        expect(response.status_code).to eq(200)

        parsed = JSON.parse(response.body)
        expect(parsed["jsonrpc"]).to eq("2.0")
        expect(parsed["id"]).to eq("init-1")

        result = parsed["result"]
        expect(result["protocolVersion"]).to eq("2025-03-26")
        expect(result["serverInfo"]["name"]).to eq("Ktistec MCP Server")
        expect(result["serverInfo"]["version"]).to eq("1.0.0")
        expect(result["capabilities"]).to be_a(JSON::Any)
        expect(result["instructions"]).to be_a(JSON::Any)
      end
    end

    context "with unknown method" do
      let(json) { %Q|{"jsonrpc": "2.0", "id": "unknown-1", "method": "unknown/method"}| }

      it "returns method not found error" do
        post "/mcp", JSON_HEADERS, json
        expect(response.status_code).to eq(404)
        parsed = JSON.parse(response.body)

        expect(parsed["jsonrpc"]).to eq("2.0")
        expect(parsed["id"]).to eq("unknown-1")
        expect(parsed["error"]["code"]).to eq(-32601)
        expect(parsed["error"]["message"].as_s).to contain("Method not found")
        expect(parsed["error"]["message"].as_s).to contain("unknown/method")
      end
    end

    context "with invalid JSON" do
      let(json) { %Q|{"invalid": json}| }

      it "returns parse error" do
        post "/mcp", JSON_HEADERS, json
        expect(response.status_code).to eq(400)

        parsed = JSON.parse(response.body)
        expect(parsed["jsonrpc"]).to eq("2.0")
        expect(parsed["id"]).to eq("null")
        expect(parsed["error"]["code"]).to eq(-32700)
        expect(parsed["error"]["message"]).to eq("Parse error")
      end
    end

    context "with invalid content type" do
      it "returns 400" do
        post "/mcp", HTTP::Headers{"Accept" => "text/html"}, "test"
        expect(response.status_code).to eq(400)
      end
    end
  end
end
