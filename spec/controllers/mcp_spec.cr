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
        expect(result["capabilities"]["resources"]).to be_a(JSON::Any)
        expect(result["capabilities"]["tools"]).to be_a(JSON::Any)
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

    context "with resources/list request" do
      let(resources_list_request) { %Q|{"jsonrpc": "2.0", "id": "resources-1", "method": "resources/list"}| }

      it "handles no resources gracefully" do
        post "/mcp", JSON_HEADERS, resources_list_request
        expect(response.status_code).to eq(200)
        parsed = JSON.parse(response.body)

        expect(parsed["result"]["resources"].as_a).to be_empty
      end

      context "given two users" do
        let_create!(account, named: alice, username: "alice")
        let_create!(account, named: bob, username: "bob")

        it "returns both users" do
          post "/mcp", JSON_HEADERS, resources_list_request
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)

          result = parsed["result"]
          resources = result["resources"].as_a
          expect(resources.size).to eq(2)

          uris = resources.map(&.["uri"].as_s)
          expect(uris).to all(start_with("ktistec://users/"))

          names = resources.map(&.["name"].as_s)
          expect(names).to contain_exactly("alice", "bob")
        end
      end
    end

    context "with resources/read request" do
      context "given a user" do
        let_create!(
          actor,
          username: "alice",
          name: "Alice",
          summary: "Alice's summary",
          icon: "https://example.com/icon.png",
          image: "https://example.com/image.png",
          attachments: [
            ActivityPub::Actor::Attachment.new(
              name: "Website",
              type: "PropertyValue",
              value: "https://example.com"
            )
          ],
          local: true,
        )
        let_create!(
          account,
          named: alice,
          username: "alice",
          actor: actor,
        )

        it "returns user data for valid URI" do
          uri = "ktistec://users/#{alice.id}"
          request = %Q|{"jsonrpc": "2.0", "id": "read-1", "method": "resources/read", "params": {"uri": "#{uri}"}}|

          post "/mcp", JSON_HEADERS, request
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)

          contents = parsed["result"]["contents"].as_a
          expect(contents.size).to eq(1)

          user = contents.first
          expect(user["uri"]).to eq(uri)
          expect(user["mimeType"]).to eq("application/json")
          expect(user["name"]).to eq("alice")

          text = user["text"].as_s
          json = JSON.parse(text)

          expect(json["name"]).to eq("Alice")
          expect(json["summary"]).to eq("Alice's summary")
          expect(json["icon"]).to eq("https://example.com/icon.png")
          expect(json["image"]).to eq("https://example.com/image.png")

          attachments = json["attachments"].as_a
          expect(attachments.size).to eq(1)

          attachment = attachments.first
          expect(attachment["type"]).to eq("PropertyValue")
          expect(attachment["name"]).to eq("Website")
          expect(attachment["value"]).to eq("https://example.com")

          urls = json["urls"].as_a
          expect(urls).to eq(["https://test.test/@alice"])
        end
      end

      it "returns error for invalid URI" do
        request = %Q|{"jsonrpc": "2.0", "id": "read-2", "method": "resources/read", "params": {"uri": "ktistec://users/999999"}}|

        post "/mcp", JSON_HEADERS, request
        expect(response.status_code).to eq(400)
        parsed = JSON.parse(response.body)

        expect(parsed["error"]["code"]).to eq(-32602)
        expect(parsed["error"]["message"]).to eq("User not found")
      end

      it "returns error for missing URI parameter" do
        request = %Q|{"jsonrpc": "2.0", "id": "read-3", "method": "resources/read", "params": {}}|

        post "/mcp", JSON_HEADERS, request
        expect(response.status_code).to eq(400)
        parsed = JSON.parse(response.body)

        expect(parsed["error"]["code"]).to eq(-32602)
        expect(parsed["error"]["message"]).to eq("Missing URI parameter")
      end
    end

    context "with tools/list request" do
      let(tools_list_request) { %Q|{"jsonrpc": "2.0", "id": "tools-1", "method": "tools/list"}| }

      it "returns empty tools array" do
        post "/mcp", JSON_HEADERS, tools_list_request
        expect(response.status_code).to eq(200)
        parsed = JSON.parse(response.body)

        expect(parsed["result"]["tools"].as_a).to be_empty
      end
    end

    context "with tools/call request" do
      let(tools_call_request) { %Q|{"jsonrpc": "2.0", "id": "call-1", "method": "tools/call", "params": {"name": "nonexistent_tool"}}| }

      it "returns protocol error for invalid tool name" do
        post "/mcp", JSON_HEADERS, tools_call_request
        expect(response.status_code).to eq(400)
        parsed = JSON.parse(response.body)

        expect(parsed["error"]["code"]).to eq(-32602)
        expect(parsed["error"]["message"]).to eq("Invalid tool name")
      end
    end
  end
end
