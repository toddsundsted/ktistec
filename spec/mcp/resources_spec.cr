require "../../src/mcp/resources"
require "../../src/models/activity_pub/actor/person"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe MCP::Resources do
  setup_spec

  let!(account) { register }

  describe ".handle_resources_list" do
    let(resources_list_request) do
      JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "resources-1", "method": "resources/list"}|)
    end

    it "returns the information resource" do
      response = described_class.handle_resources_list(resources_list_request)

      resources = response["resources"].as_a
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
        response = described_class.handle_resources_list(resources_list_request)

        resources = response["resources"].as_a
        expect(resources.size).to eq(4) # information, an account for authentication, alice & bob

        names = resources.select(&.["uri"].as_s.starts_with?("ktistec://users/")).map(&.["name"].as_s)
        expect(names).to contain("alice", "bob")
      end
    end
  end

  describe ".handle_resources_templates_list" do
    let(templates_list_request) do
      JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "templates-1", "method": "resources/templates/list"}|)
    end

    it "returns actor and object templates" do
      response = described_class.handle_resources_templates_list(templates_list_request)

      templates = response["resourceTemplates"].as_a
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

  describe ".handle_resources_read" do
    it "returns error for missing URI parameter" do
      request = JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "read-3", "method": "resources/read", "params": {}}|)
      expect { described_class.handle_resources_read(request, account) }.to raise_error(MCPError, "Missing URI parameter")
    end

    it "returns error for unsupported schema" do
      request = JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "read-obj-3", "method": "resources/read", "params": {"uri": "ktistec://foo/bar"}}|)
      expect { described_class.handle_resources_read(request, account) }.to raise_error(MCPError, "Unsupported URI scheme: ktistec://foo/bar")
    end

    it "returns information data for valid URI" do
      request = JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "read-info-1", "method": "resources/read", "params": {"uri": "ktistec://information"}}|)

      response = described_class.handle_resources_read(request, account)

      contents = response["contents"].as_a
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
      expected_collections = ["posts", "drafts", "timeline", "notifications", "likes", "dislikes", "announces", "bookmarks", "pins", "followers", "following"]
      expect(collections).to contain_exactly(*expected_collections)

      # supported collection formats
      formats = data["collection_formats"].as_h
      expect(formats["hashtag"]).to eq(%q(hashtag#{name}))
      expect(formats["mention"]).to eq(%q(mention@{name}))

      # supported object types
      object_types = data["object_types"].as_a.map(&.as_s)
      all_types = ActivityPub::Object.all_subtypes.map(&.split("::").last)
      expect(object_types).to contain_exactly(*all_types)

      # supported actor types
      actor_types = data["actor_types"].as_a.map(&.as_s)
      all_types = ActivityPub::Actor.all_subtypes.map(&.split("::").last)
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

      it "returns user data for valid URI" do
        uri = "ktistec://users/#{alice.id}"
        request = JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "read-1", "method": "resources/read", "params": {"uri": "#{uri}"}}|)

        response = described_class.handle_resources_read(request, alice)

        contents = response["contents"].as_a
        expect(contents.size).to eq(1)

        user = contents.first
        expect(user["uri"]).to eq(uri)
        expect(user["mimeType"]).to eq("application/json")
        expect(user["name"]).to eq("alice")

        text = user["text"].as_s
        json = JSON.parse(text)

        expect(json["external_url"]).to eq(alice.iri)
        expect(json["internal_url"]).to eq("https://test.test/remote/actors/#{alice.actor.id}")
        expect(json["actor_uri"]).to eq("ktistec://actors/#{alice.actor.id}")
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
        request = JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "read-2", "method": "resources/read", "params": {"uri": "ktistec://users/999999"}}|)
        expect { described_class.handle_resources_read(request, account) }.to raise_error(MCPError, "Access denied to user")
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
      let(request) do
        JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "read-actor-1", "method": "resources/read", "params": {"uri": "#{uri}"}}|)
      end

      it "returns actor content" do
        response = described_class.handle_resources_read(request, account)

        contents = response["contents"].as_a
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
        let(request) do
          JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "read-actors-multiple", "method": "resources/read", "params": {"uri": "#{uri}"}}|)
        end

        it "returns multiple actor contents" do
          response = described_class.handle_resources_read(request, account)

          contents = response["contents"].as_a
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
        request = JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "read-actor-2", "method": "resources/read", "params": {"uri": "ktistec://actors/999999"}}|)
        expect { described_class.handle_resources_read(request, account) }.to raise_error(MCPError, "Actor not found")
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
      let(request) do
        JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "read-obj-1", "method": "resources/read", "params": {"uri": "#{uri}"}}|)
      end

      it "returns object content" do
        response = described_class.handle_resources_read(request, account)

        contents = response["contents"].as_a
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
        expect(json["dislikes"]?).to be_nil
        expect(json["announces"]?).to be_nil
        expect(json["replies"]?).to be_nil
      end

      context "and multiple objects in the URI" do
        let(uri) { "ktistec://objects/#{root.id},#{object.id}" }
        let(request) do
          JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "read-objects-multiple", "method": "resources/read", "params": {"uri": "#{uri}"}}|)
        end

        it "returns multiple object contents" do
          response = described_class.handle_resources_read(request, account)

          contents = response["contents"].as_a
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
          response = described_class.handle_resources_read(request, account)

          text = response["contents"].as_a.first["text"].as_s
          json = JSON.parse(text)

          expect(json["media_type"]).to eq("text/html")
          expect(json["content"]).to match(%r|<h1>This is the content</h1>|)
        end
      end

      context "with Markdown content" do
        before_each { object.assign(media_type: "text/markdown", content: "# This is the content").save }

        it "returns HTML content" do
          response = described_class.handle_resources_read(request, account)

          text = response["contents"].as_a.first["text"].as_s
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
          response = described_class.handle_resources_read(request, account)

          text = response["contents"].as_a.first["text"].as_s
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
          response = described_class.handle_resources_read(request, account)

          text = response["contents"].as_a.first["text"].as_s
          json = JSON.parse(text)

          likes = json["likes"].as_h
          expect(likes["count"]).to eq(1)

          actors = likes["actors"].as_a
          expect(actors.size).to eq(1)

          actor = actors.first
          expect(actor["uri"]).to eq("ktistec://actors/#{liker.id}")
          expect(actor["handle"]).to eq(liker.handle)
          expect(actor["liked_at"]).not_to be_nil
        end
      end

      context "with a dislike" do
        let_create(:actor, named: disliker)
        let_create!(:dislike, actor: disliker, object: object)

        it "includes dislikes field in object JSON" do
          response = described_class.handle_resources_read(request, account)

          text = response["contents"].as_a.first["text"].as_s
          json = JSON.parse(text)

          dislikes = json["dislikes"].as_h
          expect(dislikes["count"]).to eq(1)

          actors = dislikes["actors"].as_a
          expect(actors.size).to eq(1)

          actor = actors.first
          expect(actor["uri"]).to eq("ktistec://actors/#{disliker.id}")
          expect(actor["handle"]).to eq(disliker.handle)
          expect(actor["disliked_at"]).not_to be_nil
        end
      end

      context "with an announce" do
        let_create(:actor, named: announcer)
        let_create!(:announce, actor: announcer, object: object)

        it "includes announces field in object JSON" do
          response = described_class.handle_resources_read(request, account)

          text = response["contents"].as_a.first["text"].as_s
          json = JSON.parse(text)

          announces = json["announces"].as_h
          expect(announces["count"]).to eq(1)

          actors = announces["actors"].as_a
          expect(actors.size).to eq(1)

          actor = actors.first
          expect(actor["uri"]).to eq("ktistec://actors/#{announcer.id}")
          expect(actor["handle"]).to eq(announcer.handle)
          expect(actor["announced_at"]).not_to be_nil
        end
      end

      context "with replies" do
        let_create(:actor, named: replier)
        let_create!(:object,
          named: reply1,
          attributed_to: replier,
          in_reply_to: object,
          content: "This is the first reply with some content that might be quite long and should be truncated because it is long.",
          published: Time.utc(2024, 1, 2, 10, 0, 0),
        )
        let_create!(:object,
          named: reply2,
          attributed_to: replier,
          in_reply_to: object,
          content: "Short reply",
          published: Time.utc(2024, 1, 2, 11, 0, 0),
        )

        it "includes replies field in object JSON" do
          response = described_class.handle_resources_read(request, account)

          text = response["contents"].as_a.first["text"].as_s
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
        request = JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "read-obj-2", "method": "resources/read", "params": {"uri": "ktistec://objects/999999"}}|)
        expect { described_class.handle_resources_read(request, account) }.to raise_error(MCPError, "Object not found")
      end
    end
  end
end
