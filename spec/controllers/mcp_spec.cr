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

    context "with resources/list request" do
      let(resources_list_request) { %Q|{"jsonrpc": "2.0", "id": "resources-1", "method": "resources/list"}| }

      it "returns the information resource" do
        post "/mcp", authenticated_headers, resources_list_request
        expect(response.status_code).to eq(200)
        parsed = JSON.parse(response.body)

        resources = parsed["result"]["resources"].as_a
        expect(resources.size).to eq(2) # information & an account for authentication

        info_resource = resources.first
        expect(info_resource["uri"]).to eq("ktistec://information")
        expect(info_resource["name"]).to eq("Instance Information")
        expect(info_resource["mimeType"]).to eq("application/json")
      end

      context "given two users" do
        let_create!(account, named: alice, username: "alice")
        let_create!(account, named: bob, username: "bob")

        it "returns both users" do
          post "/mcp", authenticated_headers, resources_list_request
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)

          result = parsed["result"]
          resources = result["resources"].as_a
          expect(resources.size).to eq(4) # information, an account for authentication, alice & bob

          names = resources.select(&.["uri"].as_s.starts_with?("ktistec://users/")).map(&.["name"].as_s)
          expect(names).to contain("alice", "bob")
        end
      end
    end

    context "with resources/templates/list request" do
      let(templates_list_request) { %Q|{"jsonrpc": "2.0", "id": "templates-1", "method": "resources/templates/list"}| }

      it "returns actor and object templates" do
        post "/mcp", authenticated_headers, templates_list_request
        expect(response.status_code).to eq(200)
        parsed = JSON.parse(response.body)

        result = parsed["result"]
        templates = result["resourceTemplates"].as_a
        expect(templates.size).to eq(2)

        actor_template = templates[0]
        expect(actor_template["uriTemplate"]).to eq("ktistec://actors/{id*}")
        expect(actor_template["mimeType"]).to eq("application/json")
        expect(actor_template["description"]).to eq(
          "Retrieve ActivityPub actor profiles including name, summary, icon, attachments, and URLs. Supports single ID " \
          "(ktistec://actors/123) or comma-separated IDs for batch retrieval (ktistec://actors/123,456,789)."
        )
        expect(actor_template["title"]).to eq("ActivityPub Actor")
        expect(actor_template["name"]).to eq("Actor")

        object_template = templates[1]
        expect(object_template["uriTemplate"]).to eq("ktistec://objects/{id*}")
        expect(object_template["mimeType"]).to eq("application/json")
        expect(object_template["description"]).to eq(
          "Access ActivityPub posts/objects with name, summary, content, metadata, and relationships. Supports single ID " \
          "(ktistec://objects/123) or comma-separated IDs for batch retrieval (ktistec://objects/123,456,789)."
        )
        expect(object_template["title"]).to eq("ActivityPub Object")
        expect(object_template["name"]).to eq("Object")
      end
    end

    context "with resources/read request" do
      it "returns error for missing URI parameter" do
        request = %Q|{"jsonrpc": "2.0", "id": "read-3", "method": "resources/read", "params": {}}|

        post "/mcp", authenticated_headers, request
        expect_mcp_error(-32602, "Missing URI parameter")
      end

      it "returns error for unsupported schema" do
        request = %Q|{"jsonrpc": "2.0", "id": "read-obj-3", "method": "resources/read", "params": {"uri": "ktistec://foo/bar"}}|

        post "/mcp", authenticated_headers, request
        expect_mcp_error(-32602, "Unsupported URI scheme: ktistec://foo/bar")
      end

      it "returns information data for valid URI" do
        request = %Q|{"jsonrpc": "2.0", "id": "read-info-1", "method": "resources/read", "params": {"uri": "ktistec://information"}}|

        post "/mcp", authenticated_headers, request
        expect(response.status_code).to eq(200)
        parsed = JSON.parse(response.body)

        result = parsed["result"]
        contents = result["contents"].as_a
        expect(contents.size).to eq(1)

        info_data = contents.first
        expect(info_data["uri"]).to eq("ktistec://information")
        expect(info_data["name"]).to eq("Instance Information")
        expect(info_data["mimeType"]).to eq("application/json")

        data = JSON.parse(info_data["text"].as_s)

        # basic instance information
        expect(data["version"]).to eq(Ktistec::VERSION)
        expect(data["host"]).to eq(Ktistec.host)
        expect(data["description"]).to eq("Ktistec ActivityPub Server Model Context Protocol (MCP) Interface")

        # authenticated user information
        auth_user = data["authenticated_user"].as_h
        expect(auth_user["uri"]).to eq("ktistec://users/#{account.id}")
        expect(auth_user["username"]).to eq(account.username)
        expect(auth_user["language"]).to be_a(JSON::Any)
        expect(auth_user["timezone"]).to be_a(JSON::Any)

        # supported collections
        collections = data["collections"].as_a.map(&.as_s)
        expected_collections = ["posts", "drafts", "timeline", "notifications", "likes", "announcements", "followers", "following"]
        expect(collections).to contain_exactly(*expected_collections)

        # supported collection formats
        formats = data["collection_formats"].as_h
        expect(formats["hashtag"]).to eq(%q(hashtag#{name}))
        expect(formats["mention"]).to eq(%q(mention@{name}))

        # supported object types
        object_types = data["object_types"].as_a.map(&.as_s)
        all_types = {{(ActivityPub::Object.all_subclasses << ActivityPub::Object).map(&.stringify.split("::").last)}}
        expect(object_types).to contain_exactly(*all_types)

        # supported actor types
        actor_types = data["actor_types"].as_a.map(&.as_s)
        all_types = {{(ActivityPub::Actor.all_subclasses << ActivityPub::Actor).map(&.stringify.split("::").last)}}
        expect(actor_types).to contain_exactly(*all_types)

        # statistics
        stats = data["statistics"].as_h
        expect(stats["total_users"]).to be_a(JSON::Any)
        expect(stats["total_actors"]).to be_a(JSON::Any)
        expect(stats["total_objects"]).to be_a(JSON::Any)
      end

      context "given a user" do
        let_create!(
          person,
          named: actor,
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
        let_create!(
          oauth2_provider_access_token,
          token: "alice_oauth_token_123",
          account: alice,
          client: client,
          expires_at: expires_at,
          scope: scope,
        )

        def authenticated_headers
          HTTP::Headers{
            "Authorization" => "Bearer alice_oauth_token_123",
            "Content-Type" => "application/json",
            "Accept" => "application/json",
          }
        end

        it "returns user data for valid URI" do
          uri = "ktistec://users/#{alice.id}"
          request = %Q|{"jsonrpc": "2.0", "id": "read-1", "method": "resources/read", "params": {"uri": "#{uri}"}}|

          post "/mcp", authenticated_headers, request
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

          expect(json["external_url"]).to eq(alice.iri)
          expect(json["internal_url"]).to eq("https://test.test/remote/actors/#{alice.id}")
          expect(json["name"]).to eq("Alice")
          expect(json["summary"]).to eq("Alice's summary")
          expect(json["icon"]).to eq("https://example.com/icon.png")
          expect(json["image"]).to eq("https://example.com/image.png")
          expect(json["type"]).to eq("Person")

          attachments = json["attachments"].as_a
          expect(attachments.size).to eq(1)

          attachment = attachments.first
          expect(attachment["name"]).to eq("Website")
          expect(attachment["value"]).to eq("https://example.com")

          urls = json["urls"].as_a
          expect(urls).to eq(["https://test.test/@alice"])
        end

        it "returns error for invalid user URI" do
          request = %Q|{"jsonrpc": "2.0", "id": "read-2", "method": "resources/read", "params": {"uri": "ktistec://users/999999"}}|

          post "/mcp", authenticated_headers, request
          expect_mcp_error(-32602, "Access denied to user")
        end
      end

      context "given an actor" do
        let_create!(
          actor,
          named: other,
          name: "Other Actor",
        )
        let_create!(
          actor,
          name: "Test Actor",
          summary: "This is a summary",
          icon: "https://example.com/icon.png",
          image: "https://example.com/image.png"
        )
        let(uri) { "ktistec://actors/#{actor.id}" }
        let(request) { %Q|{"jsonrpc": "2.0", "id": "read-actor-1", "method": "resources/read", "params": {"uri": "#{uri}"}}| }

        it "returns actor content" do
          post "/mcp", authenticated_headers, request
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)

          result = parsed["result"]
          contents = result["contents"].as_a
          expect(contents.size).to eq(1)

          content = contents.first
          expect(content["uri"]).to eq(uri)
          expect(content["mimeType"]).to eq("application/json")
          expect(content["name"]).to eq("Test Actor")

          text = content["text"].as_s
          json = JSON.parse(text)

          expect(json["external_url"]).to eq(actor.iri)
          expect(json["internal_url"]).to eq("https://test.test/remote/actors/#{actor.id}")
          expect(json["name"]).to eq("Test Actor")
          expect(json["summary"]).to eq("This is a summary")
          expect(json["icon"]).to eq("https://example.com/icon.png")
          expect(json["image"]).to eq("https://example.com/image.png")
          expect(json["type"]).to eq("Actor")
        end

        context "and multiple actors in the URI" do
          let(uri) { "ktistec://actors/#{other.id},#{actor.id}" }
          let(request) { %Q|{"jsonrpc": "2.0", "id": "read-actors-multiple", "method": "resources/read", "params": {"uri": "#{uri}"}}| }

          it "returns multiple actor contents" do
            post "/mcp", authenticated_headers, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            result = parsed["result"]
            contents = result["contents"].as_a
            expect(contents.size).to eq(2)

            first_content = contents.find { |c| c["name"] == "Other Actor" }
            first_content = first_content.not_nil! # ensure it exists
            expect(first_content["uri"]).to eq("ktistec://actors/#{other.id}")
            expect(first_content["mimeType"]).to eq("application/json")

            second_content = contents.find { |c| c["name"] == "Test Actor" }
            second_content = second_content.not_nil! # ensure it exists
            expect(second_content["uri"]).to eq("ktistec://actors/#{actor.id}")
            expect(second_content["mimeType"]).to eq("application/json")
          end
        end

        it "returns error for invalid actor URI" do
          request = %Q|{"jsonrpc": "2.0", "id": "read-actor-2", "method": "resources/read", "params": {"uri": "ktistec://actors/999999"}}|

          post "/mcp", authenticated_headers, request
          expect_mcp_error(-32602, "Actor not found")
        end
      end

      context "given an object" do
        let_create!(
          object,
          named: root,
          name: "Root Object",
        )
        let_create!(
          object,
          name: "Test Object",
          summary: "This is a summary",
          language: "en",
          published: Time.utc(2024, 1, 1, 12, 0, 0),
          in_reply_to: root,
        )
        let(uri) { "ktistec://objects/#{object.id}" }
        let(request) { %Q|{"jsonrpc": "2.0", "id": "read-obj-1", "method": "resources/read", "params": {"uri": "#{uri}"}}| }

        it "returns object content" do
          post "/mcp", authenticated_headers, request
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

          expect(json["external_url"]).to eq(object.iri)
          expect(json["internal_url"]).to eq("https://test.test/remote/objects/#{object.id}")
          expect(json["name"]).to eq("Test Object")
          expect(json["summary"]).to eq("This is a summary")
          expect(json["language"]).to eq("en")
          expect(json["published"]).to eq("2024-01-01T12:00:00Z")
          expect(json["attributed_to"]).to eq("ktistec://actors/#{object.attributed_to.id}")
          expect(json["in_reply_to"]).to eq("ktistec://objects/#{root.id}")
          expect(json["type"]).to eq("Object")
          expect(json["likes"]?).to be_nil
          expect(json["announcements"]?).to be_nil
          expect(json["replies"]?).to be_nil
        end

        context "and multiple objects in the URI" do
          let(uri) { "ktistec://objects/#{root.id},#{object.id}" }
          let(request) { %Q|{"jsonrpc": "2.0", "id": "read-objects-multiple", "method": "resources/read", "params": {"uri": "#{uri}"}}| }

          it "returns multiple object contents" do
            post "/mcp", authenticated_headers, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            result = parsed["result"]
            contents = result["contents"].as_a
            expect(contents.size).to eq(2)

            first_content = contents.find { |c| c["name"] == "Root Object" }
            first_content = first_content.not_nil! # ensure it exists
            expect(first_content["uri"]).to eq("ktistec://objects/#{root.id}")
            expect(first_content["mimeType"]).to eq("application/json")

            second_content = contents.find { |c| c["name"] == "Test Object" }
            second_content = second_content.not_nil! # ensure it exists
            expect(second_content["uri"]).to eq("ktistec://objects/#{object.id}")
            expect(second_content["mimeType"]).to eq("application/json")
          end
        end

        context "with HTML content" do
          before_each { object.assign(media_type: "text/html", content: "<h1>This is the content</h1>").save }

          it "returns HTML content" do
            post "/mcp", authenticated_headers, request
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
            post "/mcp", authenticated_headers, request
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
            post "/mcp", authenticated_headers, request
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

        context "with a like" do
          let_create(:actor, named: liker)
          let_create!(:like, actor: liker, object: object)

          it "includes likes field in object JSON" do
            post "/mcp", authenticated_headers, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            text = parsed["result"]["contents"].as_a.first["text"].as_s
            json = JSON.parse(text)

            likes = json["likes"].as_h
            expect(likes["count"]).to eq(1)

            actors = likes["actors"].as_a
            expect(actors.size).to eq(1)
            expect(actors.first["uri"]).to eq("ktistec://actors/#{liker.id}")
          end
        end

        context "with an announcement" do
          let_create(:actor, named: announcer)
          let_create!(:announce, actor: announcer, object: object)

          it "includes announcements field in object JSON" do
            post "/mcp", authenticated_headers, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            text = parsed["result"]["contents"].as_a.first["text"].as_s
            json = JSON.parse(text)

            announcements = json["announcements"].as_h
            expect(announcements["count"]).to eq(1)

            actors = announcements["actors"].as_a
            expect(actors.size).to eq(1)
            expect(actors.first["uri"]).to eq("ktistec://actors/#{announcer.id}")
          end
        end

        context "with replies" do
          let_create(:actor, named: replier)
          let_create!(:object,
            named: reply1,
            attributed_to: replier,
            in_reply_to: object,
            content: "This is the first reply with some content that might be quite long and should be truncated because it is long.",
            published: Time.utc(2024, 1, 2, 10, 0, 0)
          )
          let_create!(:object,
            named: reply2,
            attributed_to: replier,
            in_reply_to: object,
            content: "Short reply",
            published: Time.utc(2024, 1, 2, 11, 0, 0)
          )

          it "includes replies field in object JSON" do
            post "/mcp", authenticated_headers, request
            expect(response.status_code).to eq(200)
            parsed = JSON.parse(response.body)

            text = parsed["result"]["contents"].as_a.first["text"].as_s
            json = JSON.parse(text)

            replies = json["replies"].as_h
            expect(replies["count"]).to eq(2)

            objects = replies["objects"].as_a
            expect(objects.size).to eq(2)

            # the replies should be ordered by `published`

            first_reply = objects[0]
            expect(first_reply["uri"]).to eq("ktistec://objects/#{reply2.id}")
            expect(first_reply["author"]).to eq("ktistec://actors/#{replier.id}")
            expect(first_reply["published"]).to eq("2024-01-02T11:00:00Z")
            expect(first_reply["preview"]).to eq("Short reply")

            second_reply = objects[1]
            expect(second_reply["uri"]).to eq("ktistec://objects/#{reply1.id}")
            expect(second_reply["author"]).to eq("ktistec://actors/#{replier.id}")
            expect(second_reply["published"]).to eq("2024-01-02T10:00:00Z")
            expect(second_reply["preview"]).to eq("This is the first reply with some content that might be quite long and should be truncated because i...")
          end
        end

        it "returns error for invalid object URI" do
          request = %Q|{"jsonrpc": "2.0", "id": "read-obj-2", "method": "resources/read", "params": {"uri": "ktistec://objects/999999"}}|

          post "/mcp", authenticated_headers, request
          expect_mcp_error(-32602, "Object not found")
        end
      end
    end

    MCPController.def_tool("test_tool", "A test tool for `def_tool` macro testing", [
      {name: "user", type: "string", description: "User ID", required: true, matches: /^[a-z]+[a-z0-9_]+$/},
      {name: "query", type: "string", description: "Search terms", required: true},
      {name: "limit", type: "integer", description: "Maximum results", minimum: 10, maximum: 50, default: 15},
      {name: "include_replies", type: "boolean", description: "Include reply posts", default: false},
      {name: "created_at", type: "time", description: "Creation timestamp"},
    ]) do
      JSON::Any.new({
        "user" => JSON::Any.new(user),
        "query" => JSON::Any.new(query),
        "limit" => JSON::Any.new(limit),
        "include_replies" => JSON::Any.new(include_replies),
        "created_at" => created_at ? JSON::Any.new(created_at.to_rfc3339) : JSON::Any.new(nil),
        "quota" => JSON::Any.new(99),
      })
    end

    MCPController.def_tool("test_array_tool", "A test tool for array parameter testing", [
      {name: "tags", type: "array", description: "Array of string tags", required: true, items: "string", min_items: 1, max_items: 8, unique_items: true},
      {name: "scores", type: "array", description: "Array of integer scores", required: false, items: "integer", min_items: 0, max_items: 4, default: [] of Int32},
      {name: "flags", type: "array", description: "Array of boolean flags", required: false, items: "boolean", default: [] of Bool},
    ]) do
      # ensure that they are properly typed arrays
      tag_count = tags.size
      score_sum = scores.sum
      flag_count = flags.count(true)

      JSON::Any.new({
        "tag_count" => JSON::Any.new(tag_count),
        "score_sum" => JSON::Any.new(score_sum),
        "flag_count" => JSON::Any.new(flag_count),
      })
    end

    context "with tools/list request" do
      let(tools_list_request) { %Q|{"jsonrpc": "2.0", "id": "tools-1", "method": "tools/list"}| }

      it "returns test tools" do
        post "/mcp", authenticated_headers, tools_list_request
        expect(response.status_code).to eq(200)
        parsed = JSON.parse(response.body)

        tools = parsed["result"]["tools"].as_a
        expect(tools.size).to eq(5)

        expect(tools[-2]["name"]).to eq("test_tool")
        expect(tools[-1]["name"]).to eq("test_array_tool")
      end

      context "test_tool" do
        let(test_tool) do
          post "/mcp", authenticated_headers, tools_list_request
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)
          tools = parsed["result"]["tools"].as_a
          tools[-2]
        end

        it "returns the definition" do
          expect(test_tool["name"]).to eq("test_tool")
          expect(test_tool["description"]).to eq("A test tool for `def_tool` macro testing")

          input_schema = test_tool["inputSchema"]
          expect(input_schema["type"]).to eq("object")

          properties = input_schema["properties"]

          expect(properties["user"]["type"]).to eq("string")
          expect(properties["user"]["description"]).to eq("User ID")

          expect(properties["query"]["type"]).to eq("string")
          expect(properties["query"]["description"]).to eq("Search terms")

          expect(properties["limit"]["type"]).to eq("integer")
          expect(properties["limit"]["description"]).to eq("Maximum results")
          expect(properties["limit"]["minimum"]).to eq(10)
          expect(properties["limit"]["maximum"]).to eq(50)

          expect(properties["include_replies"]["type"]).to eq("boolean")
          expect(properties["include_replies"]["description"]).to eq("Include reply posts")

          expect(properties["created_at"]["type"]).to eq("string") # "time" is represented as a JSON schema "string"
          expect(properties["created_at"]["description"]).to eq("Creation timestamp")

          required_fields = input_schema["required"].as_a.map(&.as_s)
          expect(required_fields).to contain("user")
          expect(required_fields).to contain("query")
          expect(required_fields).to_not contain("limit")
          expect(required_fields).to_not contain("include_replies")
        end
      end

      context "test_array_tool" do
        let(test_array_tool) do
          post "/mcp", authenticated_headers, tools_list_request
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)
          tools = parsed["result"]["tools"].as_a
          tools[-1]
        end

        it "returns the definition" do
          expect(test_array_tool["name"]).to eq("test_array_tool")
          expect(test_array_tool["description"]).to eq("A test tool for array parameter testing")

          input_schema = test_array_tool["inputSchema"]
          expect(input_schema["type"]).to eq("object")

          properties = input_schema["properties"]

          tags_schema = properties["tags"]
          expect(tags_schema["type"]).to eq("array")
          expect(tags_schema["description"]).to eq("Array of string tags")
          expect(tags_schema["items"]["type"]).to eq("string")
          expect(tags_schema["minItems"]).to eq(1)
          expect(tags_schema["maxItems"]).to eq(8)
          expect(tags_schema["uniqueItems"]).to eq(true)

          scores_schema = properties["scores"]
          expect(scores_schema["type"]).to eq("array")
          expect(scores_schema["description"]).to eq("Array of integer scores")
          expect(scores_schema["items"]["type"]).to eq("integer")
          expect(scores_schema["minItems"]).to eq(0)
          expect(scores_schema["maxItems"]).to eq(4)

          flags_schema = properties["flags"]
          expect(flags_schema["type"]).to eq("array")
          expect(flags_schema["description"]).to eq("Array of boolean flags")
          expect(flags_schema["items"]["type"]).to eq("boolean")
          expect(flags_schema["minItems"]?).to be_nil
          expect(flags_schema["maxItems"]?).to be_nil
          expect(flags_schema["uniqueItems"]?).to be_nil

          required_fields = input_schema["required"].as_a.map(&.as_s)
          expect(required_fields).to contain("tags")
          expect(required_fields).to_not contain("scores")
          expect(required_fields).to_not contain("flags")
        end
      end
    end

    context "test_tool validation" do
      it "validates and extracts arguments" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new("test_user"),
            "query" => JSON::Any.new("test query"),
            "limit" => JSON::Any.new(25),
            "include_replies" => JSON::Any.new(true),
          })
        })

        result = MCPController.handle_test_tool(params, account)
        expect(result["user"].as_s).to eq("test_user")
        expect(result["query"].as_s).to eq("test query")
        expect(result["limit"].as_i).to eq(25)
        expect(result["include_replies"].as_bool).to be_true
      end

      it "supplies default values for optional arguments" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new("test_user"),
            "query" => JSON::Any.new("test query"),
          })
        })

        result = MCPController.handle_test_tool(params, account)
        expect(result["limit"].as_i).to eq(15)
        expect(result["include_replies"].as_bool).to be_false
      end

      it "invokes block" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new("test_user"),
            "query" => JSON::Any.new("test query"),
            "limit" => JSON::Any.new(25),
            "include_replies" => JSON::Any.new(true),
          })
        })

        result = MCPController.handle_test_tool(params, account)
        expect(result["quota"].as_i).to eq(99)
      end

      it "validates missing arguments parameter" do
        params = JSON::Any.new({} of String => JSON::Any)

        expect { MCPController.handle_test_tool(params, account) }.to raise_error(MCPError, /Missing arguments/)
      end

      it "validates required arguments" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({} of String => JSON::Any),
        })

        expect { MCPController.handle_test_tool(params, account) }.to raise_error(MCPError, /Missing user, query/)
      end

      it "validates string type" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new(123),
            "query" => JSON::Any.new("test query"),
          })
        })

        expect { MCPController.handle_test_tool(params, account) }.to raise_error(MCPError, /`user` must be a string/)
      end

      it "validates string regex" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new("INVALID123"),
            "query" => JSON::Any.new("test query"),
          })
        })

        expect { MCPController.handle_test_tool(params, account) }.to raise_error(MCPError, /`user` format is invalid/)
      end

      it "validates integer type" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new("test_user"),
            "query" => JSON::Any.new("test query"),
            "limit" => JSON::Any.new("not_an_integer"),
          })
        })

        expect { MCPController.handle_test_tool(params, account) }.to raise_error(MCPError, /`limit` must be an integer/)
      end

      it "validates integer maximum" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new("test_user"),
            "query" => JSON::Any.new("test query"),
            "limit" => JSON::Any.new(100),
          })
        })

        expect { MCPController.handle_test_tool(params, account) }.to raise_error(MCPError, /`limit` must be <= 50/)
      end

      it "validates integer minimum" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new("test_user"),
            "query" => JSON::Any.new("test query"),
            "limit" => JSON::Any.new(1),
          })
        })

        expect { MCPController.handle_test_tool(params, account) }.to raise_error(MCPError, /`limit` must be >= 1/)
      end

      it "validates boolean type" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new("test_user"),
            "query" => JSON::Any.new("test query"),
            "include_replies" => JSON::Any.new("not_a_boolean"),
          })
        })

        expect { MCPController.handle_test_tool(params, account) }.to raise_error(MCPError, /`include_replies` must be a boolean/)
      end

      it "validates time type" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new("test_user"),
            "query" => JSON::Any.new("test query"),
            "created_at" => JSON::Any.new(123),
          })
        })

        expect { MCPController.handle_test_tool(params, account) }.to raise_error(MCPError, /`created_at` must be a RFC3339 timestamp/)
      end

      it "validates time format" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new("test_user"),
            "query" => JSON::Any.new("test query"),
            "created_at" => JSON::Any.new("invalid-time-format"),
          })
        })

        expect { MCPController.handle_test_tool(params, account) }.to raise_error(MCPError, /`created_at` must be a RFC3339 timestamp/)
      end

      it "parses valid time strings into Time objects" do
        timestamp = "2024-01-15T10:30:00Z"
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "user" => JSON::Any.new("test_user"),
            "query" => JSON::Any.new("test query"),
            "created_at" => JSON::Any.new(timestamp),
          })
        })

        result = MCPController.handle_test_tool(params, account)
        expect(result["created_at"].as_s).to eq(timestamp)
      end
    end

    context "test_array_tool validation" do
      it "accepts valid arrays" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "tags" => JSON::Any.new(["unique", "valid", "strings"].map { |s| JSON::Any.new(s) }),
            "scores" => JSON::Any.new([1, 2, 3].map { |i| JSON::Any.new(i) }),
            "flags" => JSON::Any.new([true, false, true].map { |b| JSON::Any.new(b) }),
          })
        })

        result = MCPController.handle_test_array_tool(params, account)

        expect(result["tag_count"].as_i).to eq(3)
        expect(result["score_sum"].as_i).to eq(6)
        expect(result["flag_count"].as_i).to eq(2)
      end

      it "handles default array values" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "tags" => JSON::Any.new(["tag1", "tag2"].map { |s| JSON::Any.new(s) }),
            # scores parameter is optional, so it can be omitted to test the default value
            # flags parameter is optional, so it can be omitted to test the default value
          })
        })

        result = MCPController.handle_test_array_tool(params, account)
        expect(result["score_sum"].as_i).to eq(0)
        expect(result["flag_count"].as_i).to eq(0)
      end

      it "validates array type" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "tags" => JSON::Any.new("not_an_array"),
          })
        })

        expect { MCPController.handle_test_array_tool(params, account) }.to raise_error(MCPError, /`tags` must be an array/)
      end

      it "validates string array item types" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "tags" => JSON::Any.new([JSON::Any.new(123), JSON::Any.new("valid_string")]),
          })
        })

        expect { MCPController.handle_test_array_tool(params, account) }.to raise_error(MCPError, /`tags\[0\]` must be a string/)
      end

      it "validates integer array item types" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "tags" => JSON::Any.new(["valid", "array"].map { |s| JSON::Any.new(s) }),
            "scores" => JSON::Any.new([JSON::Any.new(1), JSON::Any.new("not_an_integer"), JSON::Any.new(3)]),
          })
        })

        expect { MCPController.handle_test_array_tool(params, account) }.to raise_error(MCPError, /`scores\[1\]` must be an integer/)
      end

      it "validates boolean array item types" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "tags" => JSON::Any.new(["valid", "array"].map { |s| JSON::Any.new(s) }),
            "flags" => JSON::Any.new([JSON::Any.new(true), JSON::Any.new(false), JSON::Any.new("not_a_boolean")]),
          })
        })

        expect { MCPController.handle_test_array_tool(params, account) }.to raise_error(MCPError, /`flags\[2\]` must be a boolean/)
      end

      it "validates minimum array size" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "tags" => JSON::Any.new([] of JSON::Any),
          })
        })

        expect { MCPController.handle_test_array_tool(params, account) }.to raise_error(MCPError, /`tags` size must be >= 1/)
      end

      it "validates maximum array size" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "tags" => JSON::Any.new(["1", "2", "3", "4", "5", "6", "7", "8", "9"].map { |s| JSON::Any.new(s) }),
          })
        })

        expect { MCPController.handle_test_array_tool(params, account) }.to raise_error(MCPError, /`tags` size must be <= 8/)
      end

      it "validates unique items constraint" do
        params = JSON::Any.new({
          "arguments" => JSON::Any.new({
            "tags" => JSON::Any.new(["unique", "array", "unique"].map { |s| JSON::Any.new(s) }),
          })
        })

        expect { MCPController.handle_test_array_tool(params, account) }.to raise_error(MCPError, /`tags` items must be unique/)
      end
    end

    context "with tools/call request" do
      let(tools_call_request) { %Q|{"jsonrpc": "2.0", "id": "call-1", "method": "tools/call", "params": {"name": "nonexistent_tool"}}| }

      it "returns protocol error for invalid tool name" do
        post "/mcp", authenticated_headers, tools_call_request
        expect_mcp_error(-32602, "Invalid tool name")
      end

      context "with paginate_collection tool" do
        private def paginate_request(id, collection, args)
          base_args = {"name" => collection}
          args_json = base_args.merge(args).map { |k, v| %Q|#{k.inspect}: #{v.inspect}| }.join(", ")
          %Q|{"jsonrpc": "2.0", "id": "#{id}", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {#{args_json}}}}|
        end

        def paginate_notifications_request(id, args = {} of String => String | Int32)
          paginate_request(id, "notifications", args)
        end

        def paginate_timeline_request(id, args = {} of String => String | Int32)
          paginate_request(id, "timeline", args)
        end

        def paginate_posts_request(id, args = {} of String => String | Int32)
          paginate_request(id, "posts", args)
        end

        def paginate_drafts_request(id, args = {} of String => String | Int32)
          paginate_request(id, "drafts", args)
        end

        def paginate_hashtag_request(id, hashtag, args = {} of String => String | Int32)
          paginate_request(id, "hashtag##{hashtag}", args)
        end

        def paginate_mention_request(id, mention, args = {} of String => String | Int32)
          paginate_request(id, "mention@#{mention}", args)
        end

        def paginate_likes_request(id, args = {} of String => String | Int32)
          paginate_request(id, "likes", args)
        end

        def paginate_announcements_request(id, args = {} of String => String | Int32)
          paginate_request(id, "announcements", args)
        end

        def paginate_followers_request(id, args = {} of String => String | Int32)
          paginate_request(id, "followers", args)
        end

        def paginate_following_request(id, args = {} of String => String | Int32)
          paginate_request(id, "following", args)
        end

        def expect_paginated_response(expected_size, has_more = false)
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)
          result = parsed["result"]
          content = result["content"].as_a
          expect(content.size).to eq(1)
          data = JSON.parse(content.first["text"].as_s)
          expect(data["objects"].as_a.size).to eq(expected_size)
          expect(data["more"]).to eq(has_more)
          data["objects"].as_a
        end

        it "returns error for invalid collection name" do
          request = paginate_timeline_request("paginate-8", {"name" => "does_not_exist"})

          post "/mcp", authenticated_headers, request
          expect_mcp_error(-32602, "`does_not_exist` unsupported")
        end

        context "with a mention in the notifications" do
          let_create(:object, attributed_to: account.actor)
          let_create(:create, actor: account.actor, object: object)

          before_each do
            put_in_notifications(account.actor, mention: create)
          end

          it "returns notifications objects for valid request" do
            request = paginate_notifications_request("paginate-notifications-1")

            post "/mcp", authenticated_headers, request
            notifications = expect_paginated_response(1, false)
            expect(notifications.size).to eq(1)

            mention = notifications.first
            expect(mention["type"]).to eq("mention")
            expect(mention["object"]).to eq("ktistec://objects/#{object.id}")
            expect(mention["action_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
            expect(mention["created_at"]).not_to be_nil
          end
        end

        context "with a reply in the notifications" do
          let_create(:object, attributed_to: account.actor)
          let_create(:create, actor: account.actor, object: object)

          before_each do
            put_in_notifications(account.actor, reply: create)
          end

          it "returns reply notification for valid request" do
            request = paginate_notifications_request("paginate-notifications-2")

            post "/mcp", authenticated_headers, request
            notifications = expect_paginated_response(1, false)
            expect(notifications.size).to eq(1)

            reply = notifications.first
            expect(reply["type"]).to eq("reply")
            expect(reply["object"]).to eq("ktistec://objects/#{object.id}")
            expect(reply["action_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
            expect(reply["created_at"]).not_to be_nil
          end
        end

        context "with a follow in the notifications" do
          let_create(:actor, named: bob)
          let_create(:follow, actor: bob, object: account.actor)

          before_each do
            put_in_notifications(account.actor, follow)
          end

          it "returns follow notification for valid request" do
            request = paginate_notifications_request("paginate-notifications-3")

            post "/mcp", authenticated_headers, request
            notifications = expect_paginated_response(1, false)
            expect(notifications.size).to eq(1)

            follow_notification = notifications.first
            expect(follow_notification["type"]).to eq("follow")
            expect(follow_notification["status"]).to eq("new")
            expect(follow_notification["actor"]).to eq("ktistec://actors/#{bob.id}")
            expect(follow_notification["object"]).to eq("ktistec://users/#{account.actor.id}")
            expect(follow_notification["action_url"]).to eq("#{Ktistec.host}/remote/actors/#{bob.id}")
            expect(follow_notification["created_at"]).not_to be_nil
          end

          context "that is accepted" do
            let_create!(:accept, actor: account.actor, object: follow)

            it "returns accepted follow notification" do
              request = paginate_notifications_request("paginate-notifications-4")

              post "/mcp", authenticated_headers, request
              notifications = expect_paginated_response(1, false)
              expect(notifications.size).to eq(1)

              follow_notification = notifications.first
              expect(follow_notification["status"]).to eq("accepted")
            end
          end

          context "that is rejected" do
            let_create!(:reject, actor: account.actor, object: follow)

            it "returns rejected follow notification" do
              request = paginate_notifications_request("paginate-notifications-5")

              post "/mcp", authenticated_headers, request
              notifications = expect_paginated_response(1, false)
              expect(notifications.size).to eq(1)

              follow_notification = notifications.first
              expect(follow_notification["status"]).to eq("rejected")
            end
          end
        end

        context "with a like in the notifications" do
          let_create(:actor, named: bob)
          let_create(:object, attributed_to: account.actor)
          let_create(:like, actor: bob, object: object)

          before_each do
            put_in_notifications(account.actor, like)
          end

          it "returns like notification for valid request" do
            request = paginate_notifications_request("paginate-notifications-6")

            post "/mcp", authenticated_headers, request
            notifications = expect_paginated_response(1, false)
            expect(notifications.size).to eq(1)

            like_notification = notifications.first
            expect(like_notification["type"]).to eq("like")
            expect(like_notification["actor"]).to eq("ktistec://actors/#{bob.id}")
            expect(like_notification["object"]).to eq("ktistec://objects/#{object.id}")
            expect(like_notification["action_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
            expect(like_notification["created_at"]).not_to be_nil
          end
        end

        context "with an announce in the notifications" do
          let_create(:actor, named: bob)
          let_create(:object, attributed_to: account.actor)
          let_create(:announce, actor: bob, object: object)

          before_each do
            put_in_notifications(account.actor, announce)
          end

          it "returns announce notification for valid request" do
            request = paginate_notifications_request("paginate-notifications-7")

            post "/mcp", authenticated_headers, request
            notifications = expect_paginated_response(1, false)
            expect(notifications.size).to eq(1)

            announce_notification = notifications.first
            expect(announce_notification["type"]).to eq("announce")
            expect(announce_notification["actor"]).to eq("ktistec://actors/#{bob.id}")
            expect(announce_notification["object"]).to eq("ktistec://objects/#{object.id}")
            expect(announce_notification["action_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
            expect(announce_notification["created_at"]).not_to be_nil
          end
        end

        context "with a new post to a followed hashtag in the notifications" do
          let_create!(:notification_follow_hashtag, owner: account.actor, name: "rails")

          it "returns follow hashtag notification for valid request" do
            request = paginate_notifications_request("paginate-notifications-9")

            post "/mcp", authenticated_headers, request
            notifications = expect_paginated_response(1, false)
            expect(notifications.size).to eq(1)

            follow_hashtag_notification = notifications.first
            expect(follow_hashtag_notification["type"]).to eq("follow_hashtag")
            expect(follow_hashtag_notification["hashtag"]).to eq("rails")
            expect(follow_hashtag_notification["action_url"]).to eq("#{Ktistec.host}/tags/rails")
            expect(follow_hashtag_notification["created_at"]).not_to be_nil
          end
        end

        context "with a new post to a followed mention in the notifications" do
          let_create!(:notification_follow_mention, owner: account.actor, name: "alice@example.com")

          it "returns follow mention notification for valid request" do
            request = paginate_notifications_request("paginate-notifications-10")

            post "/mcp", authenticated_headers, request
            notifications = expect_paginated_response(1, false)
            expect(notifications.size).to eq(1)

            follow_mention_notification = notifications.first
            expect(follow_mention_notification["type"]).to eq("follow_mention")
            expect(follow_mention_notification["mention"]).to eq("alice@example.com")
            expect(follow_mention_notification["action_url"]).to eq("#{Ktistec.host}/mentions/alice@example.com")
            expect(follow_mention_notification["created_at"]).not_to be_nil
          end
        end

        context "with a new post to a followed thread in the notifications" do
          let_create(:object, attributed_to: account.actor)
          let_create!(:notification_follow_thread, owner: account.actor, object: object)

          it "returns follow thread notification for valid request" do
            request = paginate_notifications_request("paginate-notifications-8")

            post "/mcp", authenticated_headers, request
            notifications = expect_paginated_response(1, false)
            expect(notifications.size).to eq(1)

            follow_thread_notification = notifications.first
            expect(follow_thread_notification["type"]).to eq("follow_thread")
            expect(follow_thread_notification["thread"]).to eq(object.thread)
            expect(follow_thread_notification["action_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}/thread")
            expect(follow_thread_notification["created_at"]).not_to be_nil
          end
        end

        context "with an object in the timeline" do
          let_create!(:object, attributed_to: account.actor)

          before_each do
            put_in_timeline(account.actor, object)
          end

          it "returns timeline objects for valid request" do
            request = paginate_timeline_request("paginate-9")

            post "/mcp", authenticated_headers, request
            objects = expect_paginated_response(1, false)
            expect(objects).to eq(["ktistec://objects/#{object.id}"])
          end
        end

        context "with an object in actor's posts" do
          let_create!(:object, attributed_to: account.actor)
          let_create!(:create, actor: account.actor, object: object)

          before_each do
            put_in_outbox(account.actor, create)
          end

          it "returns posts objects for valid request" do
            request = paginate_posts_request("paginate-posts-1")

            post "/mcp", authenticated_headers, request
            objects = expect_paginated_response(1, false)
            expect(objects).to eq(["ktistec://objects/#{object.id}"])
          end
        end

        context "with a draft object for actor" do
          let_create!(:object, attributed_to: account.actor, published: nil)

          it "returns draft objects for valid request" do
            request = paginate_drafts_request("paginate-drafts-1")

            post "/mcp", authenticated_headers, request
            objects = expect_paginated_response(1, false)
            expect(objects).to eq(["ktistec://objects/#{object.id}"])
          end
        end

        context "with page and/or size parameters" do
          before_each do
            25.times do |i|
              object = Factory.create(:object)
              put_in_timeline(account.actor, object)
            end
          end

          it "returns 10 objects by default" do
            request = paginate_timeline_request("paginate-size-1")

            post "/mcp", authenticated_headers, request
            expect_paginated_response(10, true)
          end

          it "returns the 3rd page of objects" do
            request = paginate_timeline_request("paginate-10", {"page" => 3})

            post "/mcp", authenticated_headers, request
            expect_paginated_response(5, false)
          end

          it "returns specified number of objects when size is provided" do
            request = paginate_timeline_request("paginate-size-2", {"size" => 5})

            post "/mcp", authenticated_headers, request
            expect_paginated_response(5, true)
          end

          it "returns maximum number of objects when size equals limit" do
            request = paginate_timeline_request("paginate-size-3", {"size" => 20})

            post "/mcp", authenticated_headers, request
            expect_paginated_response(20, true)
          end

          it "works correctly with both page and size parameters" do
            request = paginate_timeline_request("paginate-size-8", {"page" => 2, "size" => 5})

            post "/mcp", authenticated_headers, request
            expect_paginated_response(5, true)
          end
        end

        context "with a hashtag collection" do
          let_create!(
            :object,
            named: tagged_post,
            attributed_to: account.actor,
            content: "Post with #technology hashtag",
            published: Time.utc(2024, 1, 1, 10, 0, 0)
          )
          let_create!(
            :hashtag,
            name: "technology",
            subject: tagged_post
          )

          it "returns hashtag objects for valid hashtag" do
            request = paginate_hashtag_request("paginate-hashtag-1", "technology")

            post "/mcp", authenticated_headers, request
            objects = expect_paginated_response(1, false)
            expect(objects.first).to eq("ktistec://objects/#{tagged_post.id}")
          end

          it "returns error for non-existent hashtag" do
            request = paginate_hashtag_request("paginate-hashtag-2", "nonexistent")

            post "/mcp", authenticated_headers, request
            expect_mcp_error(-32602, "Hashtag 'nonexistent' not found")
          end

          it "supports pagination for hashtag collections" do
            post2 = Factory.create(
              :object,
              attributed_to: account.actor,
              content: "Another #technology post",
              published: Time.utc(2024, 1, 2, 10, 0, 0)
            )
            Factory.create(
              :hashtag,
              name: "technology",
              subject: post2
            )

            request = paginate_hashtag_request("paginate-hashtag-3", "technology", {"size" => 1})

            post "/mcp", authenticated_headers, request
            objects = expect_paginated_response(1, true)
            # returns most recent post first
            expect(objects.first).to eq("ktistec://objects/#{post2.id}")
          end
        end

        context "with a mention collection" do
          let_create!(
            :object,
            named: mentioned_post,
            attributed_to: account.actor,
            content: "Hey @testuser@example.com check this out!",
            published: Time.utc(2024, 1, 1, 10, 0, 0)
          )
          let_create!(:mention,
            name: "testuser@example.com",
            subject: mentioned_post
          )

          it "returns mention objects for valid mention" do
            request = paginate_mention_request("paginate-mention-1", "testuser@example.com")

            post "/mcp", authenticated_headers, request
            objects = expect_paginated_response(1, false)
            expect(objects.first).to eq("ktistec://objects/#{mentioned_post.id}")
          end

          it "returns error for non-existent mention" do
            request = paginate_mention_request("paginate-mention-2", "nonexistent@example.com")

            post "/mcp", authenticated_headers, request
            expect_mcp_error(-32602, "Mention 'nonexistent@example.com' not found")
          end

          it "supports pagination for mention collections" do
            post2 = Factory.create(
              :object,
              attributed_to: account.actor,
              content: "Another post mentioning @testuser@example.com",
              published: Time.utc(2024, 1, 2, 10, 0, 0)
            )
            Factory.create(
              :mention,
              name: "testuser@example.com",
              subject: post2
            )

            request = paginate_mention_request("paginate-mention-3", "testuser@example.com", {"size" => 1})

            post "/mcp", authenticated_headers, request
            objects = expect_paginated_response(1, true)
            # returns most recent post first
            expect(objects.first).to eq("ktistec://objects/#{post2.id}")
          end
        end

        context "with a liked object" do
          let_create(:object, named: liked_post, attributed_to: account.actor)

          it "is empty" do
            request = paginate_likes_request("paginate-likes-1")

            post "/mcp", authenticated_headers, request
            objects = expect_paginated_response(0, false)
            expect(objects).to be_empty
          end

          context "and a like" do
            let_create!(:like, named: nil, actor: account.actor, object: liked_post)

            it "returns liked objects" do
              request = paginate_likes_request("paginate-likes-2")

              post "/mcp", authenticated_headers, request
              objects = expect_paginated_response(1, false)
              expect(objects.first).to eq("ktistec://objects/#{liked_post.id}")
            end

            context "and another liked object" do
              let_create(:object, named: post, attributed_to: account.actor)
              let_create!(:like, named: nil, actor: account.actor, object: post)

              it "supports pagination for likes collection" do
                request = paginate_likes_request("paginate-likes-3", {"size" => 1})

                post "/mcp", authenticated_headers, request
                objects = expect_paginated_response(1, true)
                # returns most recent like first
                expect(objects.first).to eq("ktistec://objects/#{post.id}")
              end
            end
          end
        end

        context "with an announced object" do
          let_create(:object, named: announced_post, attributed_to: account.actor)

          it "is empty" do
            request = paginate_announcements_request("paginate-announcements-1")

            post "/mcp", authenticated_headers, request
            objects = expect_paginated_response(0, false)
            expect(objects).to be_empty
          end

          context "and an announcement" do
            let_create!(:announce, named: nil, actor: account.actor, object: announced_post)

            it "returns announced objects" do
              request = paginate_announcements_request("paginate-announcements-2")

              post "/mcp", authenticated_headers, request
              objects = expect_paginated_response(1, false)
              expect(objects.first).to eq("ktistec://objects/#{announced_post.id}")
            end

            context "and another announced object" do
              let_create(:object, named: post, attributed_to: account.actor)
              let_create!(:announce, named: nil, actor: account.actor, object: post)

              it "supports pagination for announcements collection" do
                request = paginate_announcements_request("paginate-announcements-3", {"size" => 1})

                post "/mcp", authenticated_headers, request
                objects = expect_paginated_response(1, true)
                # returns most recent announcement first
                expect(objects.first).to eq("ktistec://objects/#{post.id}")
              end
            end
          end
        end

        context "for followers" do
          let_create(:actor, named: follower)

          it "is empty given no followers" do
            request = paginate_followers_request("paginate-followers-1")

            post "/mcp", authenticated_headers, request
            objects = expect_paginated_response(0, false)
            expect(objects).to be_empty
          end

          context "with a follower" do
            let_create!(:follow_relationship, named: nil, actor: follower, object: account.actor, confirmed: true)

            it "returns follower relationships" do
              request = paginate_followers_request("paginate-followers-2")

              post "/mcp", authenticated_headers, request
              objects = expect_paginated_response(1, false)
              expect(objects.size).to eq(1)

              relationship = objects.first.as_h
              expect(relationship["actor"]).to eq("ktistec://actors/#{follower.id}")
              expect(relationship["confirmed"]).to eq(true)
            end

            context "and an unconfirmed follower" do
              let_create(:actor, named: unconfirmed_follower)
              let_create!(:follow_relationship, named: nil, actor: unconfirmed_follower, object: account.actor, confirmed: false)

              it "includes both confirmed and unconfirmed followers" do
                request = paginate_followers_request("paginate-followers-3")

                post "/mcp", authenticated_headers, request
                objects = expect_paginated_response(2, false)
                expect(objects.size).to eq(2)

                unconfirmed_relationship = objects[0].as_h
                expect(unconfirmed_relationship["actor"]).to eq("ktistec://actors/#{unconfirmed_follower.id}")
                expect(unconfirmed_relationship["confirmed"]).to eq(false)

                confirmed_relationship = objects[1].as_h
                expect(confirmed_relationship["actor"]).to eq("ktistec://actors/#{follower.id}")
                expect(confirmed_relationship["confirmed"]).to eq(true)
              end

              it "supports pagination for followers collection" do
                request = paginate_followers_request("paginate-followers-4", {"size" => 1})

                post "/mcp", authenticated_headers, request
                objects = expect_paginated_response(1, true)
                expect(objects.size).to eq(1)

                # returns most recent follower first
                relationship = objects.first.as_h
                expect(relationship["actor"]).to eq("ktistec://actors/#{unconfirmed_follower.id}")
              end
            end
          end
        end

        context "for following" do
          let_create(:actor, named: followed_actor)

          it "is empty given no following" do
            request = paginate_following_request("paginate-following-1")

            post "/mcp", authenticated_headers, request
            objects = expect_paginated_response(0, false)
            expect(objects).to be_empty
          end

          context "with following" do
            let_create!(:follow_relationship, named: nil, actor: account.actor, object: followed_actor, confirmed: true)

            it "returns following relationships" do
              request = paginate_following_request("paginate-following-2")

              post "/mcp", authenticated_headers, request
              objects = expect_paginated_response(1, false)
              expect(objects.size).to eq(1)

              relationship = objects.first.as_h
              expect(relationship["actor"]).to eq("ktistec://actors/#{followed_actor.id}")
              expect(relationship["confirmed"]).to eq(true)
            end

            context "and an unconfirmed following" do
              let_create(:actor, named: unconfirmed_followed)
              let_create!(:follow_relationship, named: nil, actor: account.actor, object: unconfirmed_followed, confirmed: false)

              it "includes both confirmed and unconfirmed following" do
                request = paginate_following_request("paginate-following-3")

                post "/mcp", authenticated_headers, request
                objects = expect_paginated_response(2, false)
                expect(objects.size).to eq(2)

                unconfirmed_relationship = objects[0].as_h
                expect(unconfirmed_relationship["actor"]).to eq("ktistec://actors/#{unconfirmed_followed.id}")
                expect(unconfirmed_relationship["confirmed"]).to eq(false)

                confirmed_relationship = objects[1].as_h
                expect(confirmed_relationship["actor"]).to eq("ktistec://actors/#{followed_actor.id}")
                expect(confirmed_relationship["confirmed"]).to eq(true)
              end

              it "supports pagination for following collection" do
                request = paginate_following_request("paginate-following-4", {"size" => 1})

                post "/mcp", authenticated_headers, request
                objects = expect_paginated_response(1, true)
                expect(objects.size).to eq(1)

                # returns most recent following first
                relationship = objects.first.as_h
                expect(relationship["actor"]).to eq("ktistec://actors/#{unconfirmed_followed.id}")
              end
            end
          end
        end
      end

      context "with count_collection_since tool" do
        private def count_since_request(id, collection, args)
          base_args = {"name" => collection}
          args_json = base_args.merge(args).map { |k, v| %Q|#{k.inspect}: #{v.inspect}| }.join(", ")
          %Q|{"jsonrpc": "2.0", "id": "#{id}", "method": "tools/call", "params": {"name": "count_collection_since", "arguments": {#{args_json}}}}|
        end

        def count_notifications_since_request(id, args = {} of String => String | Int32)
          count_since_request(id, "notifications", args)
        end

        def count_timeline_since_request(id, args = {} of String => String | Int32)
          count_since_request(id, "timeline", args)
        end

        def count_posts_since_request(id, args = {} of String => String | Int32)
          count_since_request(id, "posts", args)
        end

        def count_drafts_since_request(id, args = {} of String => String | Int32)
          count_since_request(id, "drafts", args)
        end

        def count_hashtag_since_request(id, hashtag, args = {} of String => String | Int32)
          count_since_request(id, "hashtag##{hashtag}", args)
        end

        def count_mention_since_request(id, mention, args = {} of String => String | Int32)
          count_since_request(id, "mention@#{mention}", args)
        end

        def count_likes_since_request(id, args = {} of String => String | Int32)
          count_since_request(id, "likes", args)
        end

        def count_announcements_since_request(id, args = {} of String => String | Int32)
          count_since_request(id, "announcements", args)
        end

        def count_followers_since_request(id, args = {} of String => String | Int32)
          count_since_request(id, "followers", args)
        end

        def count_following_since_request(id, args = {} of String => String | Int32)
          count_since_request(id, "following", args)
        end

        def expect_count_response(expected_count)
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)
          result = parsed["result"]
          content = result["content"].as_a
          expect(content.size).to eq(1)
          data = JSON.parse(content.first["text"].as_s)
          expect(Time.parse_rfc3339(data["counted_at"].as_s)).to be_within(5.seconds).of(Time.utc)
          expect(data["count"]).to eq(expected_count)
        end

        it "returns error for invalid collection name" do
          request = count_timeline_since_request("count-8", {"name" => "does_not_exist", "since" => "2024-01-01T00:00:00Z"})

          post "/mcp", authenticated_headers, request
          expect_mcp_error(-32602, "`does_not_exist` unsupported")
        end

        it "returns zero count for empty timeline" do
          request = count_timeline_since_request("count-10", {"since" => "2024-01-01T00:00:00Z"})

          post "/mcp", authenticated_headers, request
          expect_count_response(0)
        end

        context "with notifications" do
          let_create(object, named: object1)
          let_create(object, named: object2)
          let_create(object, named: object3)
          let_create(create, named: create1, actor: account.actor, object: object1)
          let_create(create, named: create2, actor: account.actor, object: object2)
          let_create(create, named: create3, actor: account.actor, object: object3)

          before_each do
            put_in_notifications(account.actor, mention: create1)
            put_in_notifications(account.actor, mention: create2)
            put_in_notifications(account.actor, mention: create3)
          end

          # the `since` cutoff is decided based on the `created_at`
          # property of the associated relationship, which is slightly
          # later than the activity's `created_at` property, so the
          # following works...

          it "returns count of notifications since given timestamp" do
            since_time = create2.created_at.to_rfc3339
            request = count_notifications_since_request("count-notifications-1", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(2)
          end

          it "returns zero count when no notifications match timestamp" do
            since_time = (create3.created_at + 1.hour).to_rfc3339
            request = count_notifications_since_request("count-notifications-2", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(0)
          end

          it "returns total count when timestamp is before all notifications" do
            since_time = (create1.created_at - 1.hour).to_rfc3339
            request = count_notifications_since_request("count-notifications-3", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(3)
          end
        end

        context "with objects in timeline" do
          let_create(object, named: object1, attributed_to: account.actor)
          let_create(object, named: object2, attributed_to: account.actor)
          let_create(object, named: object3, attributed_to: account.actor)

          before_each do
            put_in_timeline(account.actor, object1)
            put_in_timeline(account.actor, object2)
            put_in_timeline(account.actor, object3)
          end

          # the `since` cutoff is decided based on the `created_at`
          # property of the associated relationship, which is slightly
          # later than the object's `created_at` property, so the
          # following works...

          it "returns count of objects since given timestamp" do
            since_time = object2.created_at.to_rfc3339
            request = count_timeline_since_request("count-11", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(2)
          end

          it "returns zero count when no objects match timestamp" do
            since_time = (object3.created_at + 1.hour).to_rfc3339
            request = count_timeline_since_request("count-12", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(0)
          end

          it "returns total count when timestamp is before all objects" do
            since_time = (object1.created_at - 1.hour).to_rfc3339
            request = count_timeline_since_request("count-13", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(3)
          end
        end

        context "with objects in actor's posts" do
          let_create(:object, named: object1, attributed_to: account.actor)
          let_create(:object, named: object2, attributed_to: account.actor)
          let_create(:object, named: object3, attributed_to: account.actor)
          let_create(:create, named: create1, actor: account.actor, object: object1)
          let_create(:create, named: create2, actor: account.actor, object: object2)
          let_create(:create, named: create3, actor: account.actor, object: object3)

          before_each do
            put_in_outbox(account.actor, create1)
            put_in_outbox(account.actor, create2)
            put_in_outbox(account.actor, create3)
          end

          # the `since` cutoff is decided based on the `created_at`
          # property of the associated relationship, which is slightly
          # later than the object's `created_at` property, so the
          # following works...

          it "returns count of posts since given timestamp" do
            since_time = object2.created_at.to_rfc3339
            request = count_posts_since_request("count-posts-1", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(2)
          end

          it "returns zero count when no posts match timestamp" do
            since_time = (object3.created_at + 1.hour).to_rfc3339
            request = count_posts_since_request("count-posts-2", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(0)
          end

          it "returns total count when timestamp is before all posts" do
            since_time = (object1.created_at - 1.hour).to_rfc3339
            request = count_posts_since_request("count-posts-3", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(3)
          end
        end

        context "with draft objects for actor" do
          let_create!(:object, named: object1, attributed_to: account.actor, published: nil)
          let_create!(:object, named: object2, attributed_to: account.actor, published: nil)
          let_create!(:object, named: object3, attributed_to: account.actor, published: nil)

          it "returns count of drafts since given timestamp" do
            since_time = (object2.created_at - 1.second).to_rfc3339
            request = count_drafts_since_request("count-drafts-1", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(2)
          end

          it "returns zero count when no drafts match timestamp" do
            since_time = (object3.created_at + 1.hour).to_rfc3339
            request = count_drafts_since_request("count-drafts-2", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(0)
          end

          it "returns total count when timestamp is before all drafts" do
            since_time = (object1.created_at - 1.hour).to_rfc3339
            request = count_drafts_since_request("count-drafts-3", {"since" => since_time})

            post "/mcp", authenticated_headers, request
            expect_count_response(3)
          end
        end

        context "with a hashtag collection" do
          let_create!(
            :object,
            named: tagged_post,
            attributed_to: account.actor,
            content: "Post with #testhashtag",
            published: Time.utc(2024, 1, 1, 10, 0, 0)
          )
          let_create!(
            :hashtag,
            name: "testhashtag",
            subject: tagged_post
          )

          # time-based counting not supported

          it "returns error for valid hashtag" do
            request = count_hashtag_since_request("count-hashtag-1", "testhashtag", {"since" => "2024-01-01T00:00:00Z"})

            post "/mcp", authenticated_headers, request
            expect_mcp_error(-32602, "Counting not supported for hashtag collections")
          end

          it "returns error for non-existent hashtag" do
            request = count_hashtag_since_request("count-hashtag-2", "nonexistent", {"since" => "2024-01-01T00:00:00Z"})

            post "/mcp", authenticated_headers, request
            expect_mcp_error(-32602, "Hashtag 'nonexistent' not found")
          end
        end

        context "with a mention collection" do
          let_create!(
            :object,
            named: mentioned_post,
            attributed_to: account.actor,
            content: "Post mentioning @testuser@example.com",
            published: Time.utc(2024, 1, 1, 10, 0, 0)
          )
          let_create!(
            :mention,
            name: "testuser@example.com",
            subject: mentioned_post
          )

          # time-based counting not supported

          it "returns error for valid mention" do
            request = count_mention_since_request("count-mention-1", "testuser@example.com", {"since" => "2024-01-01T00:00:00Z"})

            post "/mcp", authenticated_headers, request
            expect_mcp_error(-32602, "Counting not supported for mention collections")
          end

          it "returns error for non-existent mention" do
            request = count_mention_since_request("count-mention-2", "nonexistent@example.com", {"since" => "2024-01-01T00:00:00Z"})

            post "/mcp", authenticated_headers, request
            expect_mcp_error(-32602, "Mention 'nonexistent@example.com' not found")
          end
        end

        context "with likes collection" do
          it "returns error for likes collection" do
            request = count_likes_since_request("count-likes-1", {"since" => "2024-01-01T00:00:00Z"})

            post "/mcp", authenticated_headers, request
            expect_mcp_error(-32602, "Counting not supported for likes collection")
          end
        end

        context "with announcements collection" do
          it "returns error for announcements collection (time-based counting not supported)" do
            request = count_announcements_since_request("count-announcements-1", {"since" => "2024-01-01T00:00:00Z"})

            post "/mcp", authenticated_headers, request
            expect_mcp_error(-32602, "Counting not supported for announcements collections")
          end
        end

        context "with followers collection" do
          it "returns zero count" do
            request = count_followers_since_request("count-followers-1", {"since" => "2024-01-01T00:00:00Z"})

            post "/mcp", authenticated_headers, request
            expect_count_response(0)
          end

          context "with followers" do
            let_create(:actor, named: follower)
            let_create!(:follow_relationship, actor: follower, object: account.actor, created_at: Time.utc(2024, 1, 2))

            it "returns count of followers" do
              request = count_followers_since_request("count-followers-2", {"since" => "2024-01-01T00:00:00Z"})

              post "/mcp", authenticated_headers, request
              expect_count_response(1)
            end

            it "returns zero count" do
              request = count_followers_since_request("count-followers-3", {"since" => "2024-01-03T00:00:00Z"})

              post "/mcp", authenticated_headers, request
              expect_count_response(0)
            end
          end
        end

        context "with following collection" do
          it "returns zero count" do
            request = count_following_since_request("count-following-1", {"since" => "2024-01-01T00:00:00Z"})

            post "/mcp", authenticated_headers, request
            expect_count_response(0)
          end

          context "with following" do
            let_create(:actor, named: followed_actor)
            let_create!(:follow_relationship, actor: account.actor, object: followed_actor, created_at: Time.utc(2024, 1, 2))

            it "returns count of following" do
              request = count_following_since_request("count-following-2", {"since" => "2024-01-01T00:00:00Z"})

              post "/mcp", authenticated_headers, request
              expect_count_response(1)
            end

            it "returns zero count" do
              request = count_following_since_request("count-following-3", {"since" => "2024-01-03T00:00:00Z"})

              post "/mcp", authenticated_headers, request
              expect_count_response(0)
            end
          end
        end
      end

      context "with read_resources tool" do
        let_create(:actor, named: test_actor)
        let_create(:object, named: test_object, attributed_to: account.actor)

        private def read_resources_request(id, uris)
          json_uris = uris.map(&.inspect).join(", ")
          %Q|{"jsonrpc": "2.0", "id": "#{id}", "method": "tools/call", "params": {"name": "read_resources", "arguments": {"uris": [#{json_uris}]}}}|
        end

        def expect_resources_response(expected_size)
          expect(response.status_code).to eq(200)
          parsed = JSON.parse(response.body)
          data = JSON.parse(parsed["result"]["content"][0]["text"].as_s)
          resources = data["resources"].as_a
          expect(resources.size).to eq(expected_size)
          resources
        end

        it "reads single actor resource" do
          request = read_resources_request("read-1", ["ktistec://actors/#{test_actor.id}"])

          post "/mcp", authenticated_headers, request

          resources = expect_resources_response(1)
          expect(resources[0]["uri"]).to eq("ktistec://actors/#{test_actor.id}")
        end

        it "reads single object resource" do
          request = read_resources_request("read-2", ["ktistec://objects/#{test_object.id}"])

          post "/mcp", authenticated_headers, request

          resources = expect_resources_response(1)
          expect(resources[0]["uri"]).to eq("ktistec://objects/#{test_object.id}")
        end

        it "reads information resource" do
          request = read_resources_request("read-3", ["ktistec://information"])

          post "/mcp", authenticated_headers, request

          resources = expect_resources_response(1)
          expect(resources[0]["uri"]).to eq("ktistec://information")
        end

        it "reads multiple different resource types" do
          request = read_resources_request("read-4", ["ktistec://actors/#{test_actor.id}", "ktistec://objects/#{test_object.id}", "ktistec://information"])

          post "/mcp", authenticated_headers, request

          resources = expect_resources_response(3)
          uris = resources.map(&.["uri"].as_s)
          expect(uris).to contain("ktistec://actors/#{test_actor.id}")
          expect(uris).to contain("ktistec://objects/#{test_object.id}")
          expect(uris).to contain("ktistec://information")
        end

        context "and multiple actors" do
          let_create(:actor, named: test_actor2)
          let_create(:actor, named: test_actor3)

          it "reads batched resources" do
            request = read_resources_request("read-5", ["ktistec://actors/#{test_actor.id},#{test_actor2.id},#{test_actor3.id}"])

            post "/mcp", authenticated_headers, request

            resources = expect_resources_response(3)
            uris = resources.map(&.["uri"].as_s)
            expect(uris).to contain("ktistec://actors/#{test_actor.id}")
            expect(uris).to contain("ktistec://actors/#{test_actor2.id}")
            expect(uris).to contain("ktistec://actors/#{test_actor3.id}")
          end
        end

        context "and multiple objects" do
          let_create(:object, named: test_object2, attributed_to: account.actor)
          let_create(:object, named: test_object3, attributed_to: account.actor)

          it "reads batched resources" do
            request = read_resources_request("read-6", ["ktistec://objects/#{test_object.id},#{test_object2.id},#{test_object3.id}"])

            post "/mcp", authenticated_headers, request

            resources = expect_resources_response(3)
            uris = resources.map(&.["uri"].as_s)
            expect(uris).to contain("ktistec://objects/#{test_object.id}")
            expect(uris).to contain("ktistec://objects/#{test_object2.id}")
            expect(uris).to contain("ktistec://objects/#{test_object3.id}")
          end
        end

        it "handles invalid resource URI" do
          request = read_resources_request("read-7", ["ktistec://invalid/123"])

          post "/mcp", authenticated_headers, request

          expect_mcp_error(-32602, "Unsupported URI scheme: ktistec://invalid/123")
        end
      end
    end
  end
end
