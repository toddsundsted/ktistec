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

    context "with resources/templates/list request" do
      let(templates_list_request) { %Q|{"jsonrpc": "2.0", "id": "templates-1", "method": "resources/templates/list"}| }

      it "returns object template" do
        post "/mcp", JSON_HEADERS, templates_list_request
        expect(response.status_code).to eq(200)
        parsed = JSON.parse(response.body)

        result = parsed["result"]
        templates = result["resourceTemplates"].as_a
        expect(templates.size).to eq(1)

        object_template = templates.first
        expect(object_template["uriTemplate"]).to eq("ktistec://objects/{id}")
        expect(object_template["name"]).to eq("Object")
        expect(object_template["description"]).to eq("ActivityPub objects")
        expect(object_template["mimeType"]).to eq("application/json")
      end
    end

    context "with resources/read request" do
      it "returns error for missing URI parameter" do
        request = %Q|{"jsonrpc": "2.0", "id": "read-3", "method": "resources/read", "params": {}}|

        post "/mcp", JSON_HEADERS, request
        expect(response.status_code).to eq(400)
        parsed = JSON.parse(response.body)

        expect(parsed["error"]["code"]).to eq(-32602)
        expect(parsed["error"]["message"]).to eq("Missing URI parameter")
      end

      it "returns error for unsupported schema" do
        request = %Q|{"jsonrpc": "2.0", "id": "read-obj-3", "method": "resources/read", "params": {"uri": "ktistec://foo/bar"}}|

        post "/mcp", JSON_HEADERS, request
        expect(response.status_code).to eq(400)
        parsed = JSON.parse(response.body)

        expect(parsed["error"]["code"]).to eq(-32602)
        expect(parsed["error"]["message"]).to eq("Unsupported URI scheme: ktistec://foo/bar")
      end

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

        it "returns error for invalid user URI" do
          request = %Q|{"jsonrpc": "2.0", "id": "read-2", "method": "resources/read", "params": {"uri": "ktistec://users/999999"}}|

          post "/mcp", JSON_HEADERS, request
          expect(response.status_code).to eq(400)
          parsed = JSON.parse(response.body)

          expect(parsed["error"]["code"]).to eq(-32602)
          expect(parsed["error"]["message"]).to eq("User not found")
        end
      end

      context "given an object" do
        let_create!(
          object,
          name: "Test Object",
          summary: "This is a summary",
          language: "en",
        )
        let(uri) { "ktistec://objects/#{object.id}" }
        let(request) { %Q|{"jsonrpc": "2.0", "id": "read-obj-1", "method": "resources/read", "params": {"uri": "#{uri}"}}| }

        it "returns object data for valid URI" do
          post "/mcp", JSON_HEADERS, request
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)

          result = parsed["result"]
          contents = result["contents"].as_a
          expect(contents.size).to eq(1)

          content = contents.first
          expect(content["uri"]).to eq(uri)
          expect(content["mimeType"]).to eq("application/json")
          expect(content["name"]).to eq("Test Object")

          text = content["text"].as_s
          json = JSON.parse(text)

          expect(json["name"]).to eq("Test Object")
          expect(json["summary"]).to eq("This is a summary")
          expect(json["language"]).to eq("en")
        end

        context "with HTML content" do
          before_each { object.assign(media_type: "text/html", content: "<h1>This is the content</h1>").save }

          it "returns HTML content" do
            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            text = parsed["result"]["contents"].as_a.first["text"].as_s
            json = JSON.parse(text)

            expect(json["media_type"]).to eq("text/html")
            expect(json["content"]).to match(%r|<h1>This is the content</h1>|)
          end
        end

        context "with Markdown content" do
          before_each { object.assign(media_type: "text/markdown", content: "# This is the content").save }

          it "returns HTML content" do
            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            text = parsed["result"]["contents"].as_a.first["text"].as_s
            json = JSON.parse(text)

            expect(json["media_type"]).to eq("text/markdown")
            expect(json["content"]).to match(%r|<h1>This is the content</h1>|)
          end
        end

        context "with a translation" do
          let_create!(
            translation,
            origin: object,
            name: "Translated Object",
            summary: "This is a translated summary",
            content: "This is translated content",
          )

          it "uses translation content over original content" do
            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            text = parsed["result"]["contents"].as_a.first["text"].as_s
            json = JSON.parse(text)

            expect(json["name"]).to eq("Translated Object")
            expect(json["summary"]).to eq("This is a translated summary")
            expect(json["content"]).to eq("This is translated content")
            expect(json["original_language"]).to eq("en")
            expect(json["is_translated"]).to eq(true)
          end
        end
      end

      it "returns error for invalid object URI" do
        request = %Q|{"jsonrpc": "2.0", "id": "read-obj-2", "method": "resources/read", "params": {"uri": "ktistec://objects/999999"}}|

        post "/mcp", JSON_HEADERS, request
        expect(response.status_code).to eq(400)
        parsed = JSON.parse(response.body)

        expect(parsed["error"]["code"]).to eq(-32602)
        expect(parsed["error"]["message"]).to eq("Object not found")
      end
    end

    context "with tools/list request" do
      let(tools_list_request) { %Q|{"jsonrpc": "2.0", "id": "tools-1", "method": "tools/list"}| }

      it "returns tools" do
        post "/mcp", JSON_HEADERS, tools_list_request
        expect(response.status_code).to eq(200)
        parsed = JSON.parse(response.body)

        tools = parsed["result"]["tools"].as_a
        expect(tools.size).to eq(1)

        tool = tools.first
        expect(tool["name"]).to eq("paginate_collection")
        expect(tool["description"]).to eq("Paginate through collections of objects, activities, and actors")
        expect(tool["inputSchema"]["type"]).to eq("object")
        expect(tool["inputSchema"]["required"].as_a).to contain("user")
        expect(tool["inputSchema"]["required"].as_a).to contain("name")

        size_param = tool["inputSchema"]["properties"]["size"]
        expect(size_param["type"]).to eq("integer")
        expect(size_param["minimum"]).to eq(1)
        expect(size_param["maximum"]).to eq(20)
        expect(size_param["description"].as_s).to contain("defaults to 10")
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

      context "with paginate_collection tool" do
        let_create!(account, named: alice, username: "alice")

        it "returns error for missing arguments" do
          request = %Q|{"jsonrpc": "2.0", "id": "paginate-1", "method": "tools/call", "params": {"name": "paginate_collection"}}|

          post "/mcp", JSON_HEADERS, request
          expect(response.status_code).to eq(400)
          parsed = JSON.parse(response.body)

          expect(parsed["error"]["code"]).to eq(-32602)
          expect(parsed["error"]["message"]).to eq("Missing arguments")
        end

        it "returns error for missing arguments" do
          request = %Q|{"jsonrpc": "2.0", "id": "paginate-2", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {}}}|

          post "/mcp", JSON_HEADERS, request
          expect(response.status_code).to eq(400)
          parsed = JSON.parse(response.body)

          expect(parsed["error"]["code"]).to eq(-32602)
          expect(parsed["error"]["message"]).to eq("Missing user URI, collection name")
        end

        it "returns error for missing user URI" do
          request = %Q|{"jsonrpc": "2.0", "id": "paginate-1", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"name": "timeline"}}}|

          post "/mcp", JSON_HEADERS, request
          expect(response.status_code).to eq(400)
          parsed = JSON.parse(response.body)

          expect(parsed["error"]["code"]).to eq(-32602)
          expect(parsed["error"]["message"]).to eq("Missing user URI")
        end

        it "returns error for missing collection name" do
          request = %Q|{"jsonrpc": "2.0", "id": "paginate-3", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/1"}}}|

          post "/mcp", JSON_HEADERS, request
          expect(response.status_code).to eq(400)
          parsed = JSON.parse(response.body)

          expect(parsed["error"]["code"]).to eq(-32602)
          expect(parsed["error"]["message"]).to eq("Missing collection name")
        end

        context "with valid collection name" do
          it "returns error for invalid user URI" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-4", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "invalid://uri", "name": "timeline"}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(400)
            parsed = JSON.parse(response.body)

            expect(parsed["error"]["code"]).to eq(-32602)
            expect(parsed["error"]["message"]).to eq("Invalid user URI format")
          end

          it "returns error for invalid user ID in URI" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-5", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/invalid", "name": "timeline"}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(400)
            parsed = JSON.parse(response.body)

            expect(parsed["error"]["code"]).to eq(-32602)
            expect(parsed["error"]["message"]).to eq("Invalid user ID in URI")
          end

          it "returns error for non-existent user" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-6", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/999999", "name": "timeline"}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(400)
            parsed = JSON.parse(response.body)

            expect(parsed["error"]["code"]).to eq(-32602)
            expect(parsed["error"]["message"]).to eq("User not found")
          end
        end

        context "with valid user URI" do
          it "returns error for invalid collection name" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-8", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/#{alice.id}", "name": "does_not_exist"}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(400)
            parsed = JSON.parse(response.body)

            expect(parsed["error"]["code"]).to eq(-32602)
            expect(parsed["error"]["message"]).to eq("Invalid collection name")
          end
        end

        context "with an object in the timeline" do
          let_create!(:object, attributed_to: alice.actor)

          before_each do
            put_in_timeline(alice.actor, object)
          end

          it "returns timeline objects for valid request" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-9", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/#{alice.id}", "name": "timeline"}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            result = parsed["result"]
            content = result["content"].as_a
            expect(content.size).to eq(1)

            text_content = content.first
            expect(text_content["type"]).to eq("text")

            data = JSON.parse(text_content["text"].as_s)
            expect(data["objects"].as_a).to eq(["ktistec://objects/#{object.id}"])
            expect(data["more"]).to be_false
          end
        end

        context "with page and/or size parameters" do
          before_each do
            25.times do |i|
              object = Factory.create(:object)
              put_in_timeline(alice.actor, object)
            end
          end

          it "returns 10 objects by default" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-size-1", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/#{alice.id}", "name": "timeline"}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            result = parsed["result"]
            content = result["content"].as_a
            expect(content.size).to eq(1)

            data = JSON.parse(content.first["text"].as_s)
            expect(data["objects"].as_a.size).to eq(10)
            expect(data["more"]).to be_true
          end

          it "returns the 3rd page of objects" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-10", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/#{alice.id}", "name": "timeline", "page": 3}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            result = parsed["result"]
            content = result["content"].as_a
            expect(content.size).to eq(1)

            data = JSON.parse(content.first["text"].as_s)
            expect(data["objects"].as_a.size).to eq(5)
            expect(data["more"]).to be_false
          end

          it "returns specified number of objects when size is provided" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-size-2", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/#{alice.id}", "name": "timeline", "size": 5}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            result = parsed["result"]
            content = result["content"].as_a
            expect(content.size).to eq(1)

            data = JSON.parse(content.first["text"].as_s)
            expect(data["objects"].as_a.size).to eq(5)
            expect(data["more"]).to be_true
          end

          it "returns maximum number of objects when size equals limit" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-size-3", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/#{alice.id}", "name": "timeline", "size": 20}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            result = parsed["result"]
            content = result["content"].as_a
            expect(content.size).to eq(1)

            data = JSON.parse(content.first["text"].as_s)
            expect(data["objects"].as_a.size).to eq(20)
            expect(data["more"]).to be_true
          end

          it "works correctly with both page and size parameters" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-size-8", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/#{alice.id}", "name": "timeline", "page": 2, "size": 5}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            result = parsed["result"]
            content = result["content"].as_a
            expect(content.size).to eq(1)

            data = JSON.parse(content.first["text"].as_s)
            expect(data["objects"].as_a.size).to eq(5)
            expect(data["more"]).to be_true
          end

          it "returns error for invalid page number" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-7", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/#{alice.id}", "name": "timeline", "page": 0}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(400)
            parsed = JSON.parse(response.body)

            expect(parsed["error"]["code"]).to eq(-32602)
            expect(parsed["error"]["message"]).to eq("Page must be >= 1")
          end

          it "returns error for invalid size number" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-size-5", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/#{alice.id}", "name": "timeline", "size": 0}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(400)
            parsed = JSON.parse(response.body)

            expect(parsed["error"]["code"]).to eq(-32602)
            expect(parsed["error"]["message"]).to eq("Size must be >= 1")
          end

          it "returns error for invalid size number" do
            request = %Q|{"jsonrpc": "2.0", "id": "paginate-size-7", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {"user": "ktistec://users/#{alice.id}", "name": "timeline", "size": 25}}}|

            post "/mcp", JSON_HEADERS, request
            expect(response.status_code).to eq(400)
            parsed = JSON.parse(response.body)

            expect(parsed["error"]["code"]).to eq(-32602)
            expect(parsed["error"]["message"]).to eq("Size cannot exceed 20")
          end
        end
      end
    end
  end
end
