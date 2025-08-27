require "../../src/mcp/tools"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe MCP::Tools do
  setup_spec

  let!(account) { register }

  let(now) { Time.utc }

  MCP::Tools.def_tool("test_tool", "A test tool for `def_tool` macro testing", [
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

  MCP::Tools.def_tool("test_array_tool", "A test tool for array parameter testing", [
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

      result = described_class.handle_tool_test_tool(params, account)
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

      result = described_class.handle_tool_test_tool(params, account)
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

      result = described_class.handle_tool_test_tool(params, account)
      expect(result["quota"].as_i).to eq(99)
    end

    it "validates missing arguments parameter" do
      params = JSON::Any.new({} of String => JSON::Any)

      expect { described_class.handle_tool_test_tool(params, account) }.to raise_error(MCPError, /Missing arguments/)
    end

    it "validates required arguments" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({} of String => JSON::Any),
      })

      expect { described_class.handle_tool_test_tool(params, account) }.to raise_error(MCPError, /Missing user, query/)
    end

    it "validates string type" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "user" => JSON::Any.new(123),
          "query" => JSON::Any.new("test query"),
        })
      })

      expect { described_class.handle_tool_test_tool(params, account) }.to raise_error(MCPError, /`user` must be a string/)
    end

    it "validates string regex" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "user" => JSON::Any.new("INVALID123"),
          "query" => JSON::Any.new("test query"),
        })
      })

      expect { described_class.handle_tool_test_tool(params, account) }.to raise_error(MCPError, /`user` format is invalid/)
    end

    it "validates integer type" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "user" => JSON::Any.new("test_user"),
          "query" => JSON::Any.new("test query"),
          "limit" => JSON::Any.new("not_an_integer"),
        })
      })

      expect { described_class.handle_tool_test_tool(params, account) }.to raise_error(MCPError, /`limit` must be an integer/)
    end

    it "validates integer maximum" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "user" => JSON::Any.new("test_user"),
          "query" => JSON::Any.new("test query"),
          "limit" => JSON::Any.new(100),
        })
      })

      expect { described_class.handle_tool_test_tool(params, account) }.to raise_error(MCPError, /`limit` must be <= 50/)
    end

    it "validates integer minimum" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "user" => JSON::Any.new("test_user"),
          "query" => JSON::Any.new("test query"),
          "limit" => JSON::Any.new(1),
        })
      })

      expect { described_class.handle_tool_test_tool(params, account) }.to raise_error(MCPError, /`limit` must be >= 1/)
    end

    it "validates boolean type" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "user" => JSON::Any.new("test_user"),
          "query" => JSON::Any.new("test query"),
          "include_replies" => JSON::Any.new("not_a_boolean"),
        })
      })

      expect { described_class.handle_tool_test_tool(params, account) }.to raise_error(MCPError, /`include_replies` must be a boolean/)
    end

    it "validates time type" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "user" => JSON::Any.new("test_user"),
          "query" => JSON::Any.new("test query"),
          "created_at" => JSON::Any.new(123),
        })
      })

      expect { described_class.handle_tool_test_tool(params, account) }.to raise_error(MCPError, /`created_at` must be a RFC3339 timestamp/)
    end

    it "validates time format" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "user" => JSON::Any.new("test_user"),
          "query" => JSON::Any.new("test query"),
          "created_at" => JSON::Any.new("invalid-time-format"),
        })
      })

      expect { described_class.handle_tool_test_tool(params, account) }.to raise_error(MCPError, /`created_at` must be a RFC3339 timestamp/)
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

      result = described_class.handle_tool_test_tool(params, account)
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

      result = described_class.handle_tool_test_array_tool(params, account)

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

      result = described_class.handle_tool_test_array_tool(params, account)
      expect(result["score_sum"].as_i).to eq(0)
      expect(result["flag_count"].as_i).to eq(0)
    end

    it "validates array type" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "tags" => JSON::Any.new("not_an_array"),
        })
      })

      expect { described_class.handle_tool_test_array_tool(params, account) }.to raise_error(MCPError, /`tags` must be an array/)
    end

    it "validates string array item types" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "tags" => JSON::Any.new([JSON::Any.new(123), JSON::Any.new("valid_string")]),
        })
      })

      expect { described_class.handle_tool_test_array_tool(params, account) }.to raise_error(MCPError, /`tags\[0\]` must be a string/)
    end

    it "validates integer array item types" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "tags" => JSON::Any.new(["valid", "array"].map { |s| JSON::Any.new(s) }),
          "scores" => JSON::Any.new([JSON::Any.new(1), JSON::Any.new("not_an_integer"), JSON::Any.new(3)]),
        })
      })

      expect { described_class.handle_tool_test_array_tool(params, account) }.to raise_error(MCPError, /`scores\[1\]` must be an integer/)
    end

    it "validates boolean array item types" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "tags" => JSON::Any.new(["valid", "array"].map { |s| JSON::Any.new(s) }),
          "flags" => JSON::Any.new([JSON::Any.new(true), JSON::Any.new(false), JSON::Any.new("not_a_boolean")]),
        })
      })

      expect { described_class.handle_tool_test_array_tool(params, account) }.to raise_error(MCPError, /`flags\[2\]` must be a boolean/)
    end

    it "validates minimum array size" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "tags" => JSON::Any.new([] of JSON::Any),
        })
      })

      expect { described_class.handle_tool_test_array_tool(params, account) }.to raise_error(MCPError, /`tags` size must be >= 1/)
    end

    it "validates maximum array size" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "tags" => JSON::Any.new(["1", "2", "3", "4", "5", "6", "7", "8", "9"].map { |s| JSON::Any.new(s) }),
        })
      })

      expect { described_class.handle_tool_test_array_tool(params, account) }.to raise_error(MCPError, /`tags` size must be <= 8/)
    end

    it "validates unique items constraint" do
      params = JSON::Any.new({
        "arguments" => JSON::Any.new({
          "tags" => JSON::Any.new(["unique", "array", "unique"].map { |s| JSON::Any.new(s) }),
        })
      })

      expect { described_class.handle_tool_test_array_tool(params, account) }.to raise_error(MCPError, /`tags` items must be unique/)
    end
  end

  context "with tools/list request" do
    let(tools_list_request) do
      JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "tools-1", "method": "tools/list"}|)
    end

    it "returns test tools" do
      response = described_class.handle_tools_list(tools_list_request)

      tools = response["tools"].as_a
      expect(tools.size).to eq(5)

      expect(tools[-2]["name"]).to eq("test_tool")
      expect(tools[-1]["name"]).to eq("test_array_tool")
    end

    context "test_tool" do
      let(test_tool) do
        response = described_class.handle_tools_list(tools_list_request)
        tools = response["tools"].as_a
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
        response = described_class.handle_tools_list(tools_list_request)
        tools = response["tools"].as_a
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

  context "with tools/call request" do
    let(tools_call_request) do
      JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "call-1", "method": "tools/call", "params": {"name": "nonexistent_tool"}}|)
    end

    it "returns protocol error for invalid tool name" do
      expect { described_class.handle_tools_call(tools_call_request, account) }.to raise_error(MCPError, "Invalid tool name")
    end

    context "with paginate_collection tool" do
      private def paginate_request(id, collection, args)
        base_args = {"name" => collection}
        args_json = base_args.merge(args).map { |k, v| %Q|#{k.inspect}: #{v.inspect}| }.join(", ")
        JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "#{id}", "method": "tools/call", "params": {"name": "paginate_collection", "arguments": {#{args_json}}}}|)
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

      def paginate_dislikes_request(id, args = {} of String => String | Int32)
        paginate_request(id, "dislikes", args)
      end

      def paginate_announces_request(id, args = {} of String => String | Int32)
        paginate_request(id, "announces", args)
      end

      def paginate_followers_request(id, args = {} of String => String | Int32)
        paginate_request(id, "followers", args)
      end

      def paginate_following_request(id, args = {} of String => String | Int32)
        paginate_request(id, "following", args)
      end

      def expect_paginated_response(request, expected_size, has_more = false)
        response = described_class.handle_tools_call(request, account)
        content = response["content"].as_a
        expect(content.size).to eq(1)
        data = JSON.parse(content.first["text"].as_s)
        expect(data["objects"].as_a.size).to eq(expected_size)
        expect(data["more"]).to eq(has_more)
        data["objects"].as_a
      end

      it "returns error for invalid collection name" do
        request = paginate_timeline_request("paginate-8", {"name" => "does_not_exist"})
        expect { described_class.handle_tools_call(request, account) }.to raise_error(MCPError, "`does_not_exist` unsupported")
      end

      context "with a mention in the notifications" do
        let_create(:object)
        let_create(:create, object: object)

        before_each do
          put_in_notifications(account.actor, mention: create)
        end

        it "returns notifications objects for valid request" do
          request = paginate_notifications_request("paginate-notifications-1")

          notifications = expect_paginated_response(request, 1, false)

          mention = notifications.first
          expect(mention["type"]).to eq("mention")
          expect(mention["status"]).to eq("new")
          expect(mention["object"]).to eq("ktistec://objects/#{object.id}")
          expect(mention["actor"]).to eq("ktistec://actors/#{object.attributed_to.id}")
          expect(mention["action_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
          expect(mention["created_at"]).not_to be_nil
        end

        context "with a like" do
          let_create!(:like, actor: account.actor, object: object)

          it "returns liked status" do
            request = paginate_notifications_request("paginate-notifications-liked-1")

            notifications = expect_paginated_response(request, 1, false)

            mention = notifications.first
            expect(mention["status"]).to eq(["liked"])
          end
        end
      end

      context "with a reply in the notifications" do
        let_create(:object, named: :parent, attributed_to: account.actor)
        let_create(:object, in_reply_to: parent)
        let_create(:create, object: object)

        before_each do
          put_in_notifications(account.actor, reply: create)
        end

        it "returns reply notification for valid request" do
          request = paginate_notifications_request("paginate-notifications-2")

          notifications = expect_paginated_response(request, 1, false)

          reply = notifications.first
          expect(reply["type"]).to eq("reply")
          expect(reply["status"]).to eq("new")
          expect(reply["object"]).to eq("ktistec://objects/#{object.id}")
          expect(reply["actor"]).to eq("ktistec://actors/#{object.attributed_to.id}")
          expect(reply["parent"]).to eq("ktistec://objects/#{object.in_reply_to.id}")
          expect(reply["action_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
          expect(reply["created_at"]).not_to be_nil
        end

        context "with a reply" do
          let_create!(:object, named: :user_reply, attributed_to: account.actor, in_reply_to: object)

          it "returns replied status" do
            request = paginate_notifications_request("paginate-notifications-replied-1")

            notifications = expect_paginated_response(request, 1, false)

            reply = notifications.first
            expect(reply["status"]).to eq(["replied"])
          end
        end

        context "with an announce" do
          let_create!(:announce, actor: account.actor, object: object)

          it "returns announced status" do
            request = paginate_notifications_request("paginate-notifications-announced-1")

            notifications = expect_paginated_response(request, 1, false)

            reply = notifications.first
            expect(reply["status"]).to eq(["announced"])
          end
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

          notifications = expect_paginated_response(request, 1, false)

          follow_notification = notifications.first
          expect(follow_notification["type"]).to eq("follow")
          expect(follow_notification["status"]).to eq("new")
          expect(follow_notification["actor"]).to eq("ktistec://actors/#{bob.id}")
          expect(follow_notification["object"]).to eq("ktistec://users/#{account.id}")
          expect(follow_notification["action_url"]).to eq("#{Ktistec.host}/remote/actors/#{bob.id}")
          expect(follow_notification["created_at"]).not_to be_nil
        end

        context "that is accepted" do
          let_create!(:accept, actor: account.actor, object: follow)

          it "returns accepted follow notification" do
            request = paginate_notifications_request("paginate-notifications-4")

            notifications = expect_paginated_response(request, 1, false)

            follow_notification = notifications.first
            expect(follow_notification["status"]).to eq("accepted")
          end
        end

        context "that is rejected" do
          let_create!(:reject, actor: account.actor, object: follow)

          it "returns rejected follow notification" do
            request = paginate_notifications_request("paginate-notifications-5")

            notifications = expect_paginated_response(request, 1, false)

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

          notifications = expect_paginated_response(request, 1, false)

          like_notification = notifications.first
          expect(like_notification["type"]).to eq("like")
          expect(like_notification["actor"]).to eq("ktistec://actors/#{bob.id}")
          expect(like_notification["object"]).to eq("ktistec://objects/#{object.id}")
          expect(like_notification["action_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
          expect(like_notification["created_at"]).not_to be_nil
        end
      end

      context "with a dislike in the notifications" do
        let_create(:actor, named: bob)
        let_create(:object, attributed_to: account.actor)
        let_create(:dislike, actor: bob, object: object)

        before_each do
          put_in_notifications(account.actor, dislike)
        end

        it "returns dislike notification for valid request" do
          request = paginate_notifications_request("paginate-notifications-6")

          notifications = expect_paginated_response(request, 1, false)

          dislike_notification = notifications.first
          expect(dislike_notification["type"]).to eq("dislike")
          expect(dislike_notification["actor"]).to eq("ktistec://actors/#{bob.id}")
          expect(dislike_notification["object"]).to eq("ktistec://objects/#{object.id}")
          expect(dislike_notification["action_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
          expect(dislike_notification["created_at"]).not_to be_nil
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

          notifications = expect_paginated_response(request, 1, false)

          announce_notification = notifications.first
          expect(announce_notification["type"]).to eq("announce")
          expect(announce_notification["actor"]).to eq("ktistec://actors/#{bob.id}")
          expect(announce_notification["object"]).to eq("ktistec://objects/#{object.id}")
          expect(announce_notification["action_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
          expect(announce_notification["created_at"]).not_to be_nil
        end
      end

      context "with a new post to a followed hashtag in the notifications" do
        let_create!(:object, content: "Post about #rails programming", published: now)
        let_create!(:hashtag, subject: object, name: "rails")
        let_create!(:notification_follow_hashtag, owner: account.actor, name: "rails")

        it "returns follow hashtag notification for valid request" do
          request = paginate_notifications_request("paginate-notifications-9")

          notifications = expect_paginated_response(request, 1, false)

          follow_hashtag_notification = notifications.first
          expect(follow_hashtag_notification["type"]).to eq("follow_hashtag")
          expect(follow_hashtag_notification["hashtag"]).to eq("rails")
          expect(follow_hashtag_notification["latest_object"]).to eq("ktistec://objects/#{object.id}")
          expect(follow_hashtag_notification["action_url"]).to eq("#{Ktistec.host}/tags/rails")
          expect(follow_hashtag_notification["created_at"]).not_to be_nil
          created_at = Time.parse_rfc3339(follow_hashtag_notification["created_at"].as_s)
          expect(created_at).to be_within(1.second).of(notification_follow_hashtag.created_at)
        end
      end

      context "with a new post to a followed mention in the notifications" do
        let_create!(:object, content: "Hello @alice@example.com how are you?", published: now)
        let_create!(:mention, subject: object, name: "alice@example.com")
        let_create!(:notification_follow_mention, owner: account.actor, name: "alice@example.com")

        it "returns follow mention notification for valid request" do
          request = paginate_notifications_request("paginate-notifications-10")

          notifications = expect_paginated_response(request, 1, false)

          follow_mention_notification = notifications.first
          expect(follow_mention_notification["type"]).to eq("follow_mention")
          expect(follow_mention_notification["mention"]).to eq("alice@example.com")
          expect(follow_mention_notification["latest_object"]).to eq("ktistec://objects/#{object.id}")
          expect(follow_mention_notification["action_url"]).to eq("#{Ktistec.host}/mentions/alice@example.com")
          created_at = Time.parse_rfc3339(follow_mention_notification["created_at"].as_s)
          expect(created_at).to be_within(1.second).of(notification_follow_mention.created_at)
        end
      end

      context "with a new post to a followed thread in the notifications" do
        let_create(:object, attributed_to: account.actor)
        let_create!(:notification_follow_thread, owner: account.actor, object: object)

        it "returns follow thread notification for valid request" do
          request = paginate_notifications_request("paginate-notifications-8")

          notifications = expect_paginated_response(request, 1, false)

          follow_thread_notification = notifications.first
          expect(follow_thread_notification["type"]).to eq("follow_thread")
          expect(follow_thread_notification["thread"]).to eq(object.thread)
          expect(follow_thread_notification["latest_object"]).to eq("ktistec://objects/#{object.id}")
          expect(follow_thread_notification["action_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}/thread")
          created_at = Time.parse_rfc3339(follow_thread_notification["created_at"].as_s)
          expect(created_at).to be_within(1.second).of(notification_follow_thread.created_at)
        end
      end

      context "with an object in the timeline" do
        let_create!(:object, attributed_to: account.actor, published: now)

        before_each do
          put_in_timeline(account.actor, object)
        end

        it "returns timeline objects for valid request" do
          request = paginate_timeline_request("paginate-9")

          objects = expect_paginated_response(request, 1, false)

          expect(objects.size).to eq(1)
          object_data = objects.first.as_h
          expect(object_data["uri"]).to eq("ktistec://objects/#{object.id}")
          expect(object_data["external_url"]).to eq(object.iri)
          expect(object_data["internal_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
          expect(object_data["type"]).to eq("Object")
          expect(object_data["attributed_to"]).to eq("ktistec://actors/#{object.attributed_to.id}")
          expect(object_data["published"]).not_to be_nil
        end
      end

      context "with an object in actor's posts" do
        let_create!(:object, attributed_to: account.actor, published: now)
        let_create!(:create, actor: account.actor, object: object)

        before_each do
          put_in_outbox(account.actor, create)
        end

        it "returns posts objects for valid request" do
          request = paginate_posts_request("paginate-posts-1")

          objects = expect_paginated_response(request, 1, false)

          expect(objects.size).to eq(1)
          object_data = objects.first.as_h
          expect(object_data["uri"]).to eq("ktistec://objects/#{object.id}")
          expect(object_data["external_url"]).to eq(object.iri)
          expect(object_data["internal_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
          expect(object_data["type"]).to eq("Object")
          expect(object_data["attributed_to"]).to eq("ktistec://actors/#{object.attributed_to.id}")
          expect(object_data["published"]).not_to be_nil
        end
      end

      context "with a draft object for actor" do
        let_create!(:object, attributed_to: account.actor, published: nil, content: "Draft content")

        it "returns draft objects for valid request" do
          request = paginate_drafts_request("paginate-drafts-1")

          objects = expect_paginated_response(request, 1, false)

          expect(objects.size).to eq(1)
          object_data = objects.first.as_h
          expect(object_data["uri"]).to eq("ktistec://objects/#{object.id}")
          expect(object_data["external_url"]).to eq(object.iri)
          expect(object_data["internal_url"]).to eq("#{Ktistec.host}/remote/objects/#{object.id}")
          expect(object_data["type"]).to eq("Object")
          expect(object_data["attributed_to"]).to eq("ktistec://actors/#{object.attributed_to.id}")
          expect(object_data["content"]).to eq("Draft content")
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

          expect_paginated_response(request, 10, true)
        end

        it "returns the 3rd page of objects" do
          request = paginate_timeline_request("paginate-10", {"page" => 3})

          expect_paginated_response(request, 5, false)
        end

        it "returns specified number of objects when size is provided" do
          request = paginate_timeline_request("paginate-size-2", {"size" => 5})

          expect_paginated_response(request, 5, true)
        end

        it "returns maximum number of objects when size equals limit" do
          request = paginate_timeline_request("paginate-size-3", {"size" => 20})

          expect_paginated_response(request, 20, true)
        end

        it "works correctly with both page and size parameters" do
          request = paginate_timeline_request("paginate-size-8", {"page" => 2, "size" => 5})

          expect_paginated_response(request, 5, true)
        end
      end

      context "with a hashtag collection" do
        let_create!(
          :object,
          named: tagged_post,
          attributed_to: account.actor,
          content: "Post with #technology hashtag",
          published: Time.utc(2024, 1, 1, 10, 0, 0),
        )
        let_create!(
          :hashtag,
          named: nil,
          name: "technology",
          subject: tagged_post,
        )

        it "returns hashtag objects for valid hashtag" do
          request = paginate_hashtag_request("paginate-hashtag-1", "technology")

          objects = expect_paginated_response(request, 1, false)

          expect(objects.size).to eq(1)
          object_data = objects.first.as_h
          expect(object_data["uri"]).to eq("ktistec://objects/#{tagged_post.id}")
          expect(object_data["external_url"]).to eq(tagged_post.iri)
          expect(object_data["internal_url"]).to eq("#{Ktistec.host}/remote/objects/#{tagged_post.id}")
          expect(object_data["type"]).to eq("Object")
          expect(object_data["attributed_to"]).to eq("ktistec://actors/#{tagged_post.attributed_to.id}")
          expect(object_data["content"]).to eq("Post with #technology hashtag")
          expect(object_data["published"]).not_to be_nil
        end

        it "returns empty result for non-existent hashtag" do
          request = paginate_hashtag_request("paginate-hashtag-2", "nonexistent")

          objects = expect_paginated_response(request, 0, false)
          expect(objects.size).to eq(0)
        end

        context "and a second object" do
          let_create!(
            :object,
            named: post2,
            attributed_to: account.actor,
            content: "Another #technology post",
            published: Time.utc(2024, 1, 2, 10, 0, 0),
          )
          let_create!(
            :hashtag,
            named: nil,
            name: "technology",
            subject: post2,
          )

          it "supports pagination for hashtag collections" do
            request = paginate_hashtag_request("paginate-hashtag-3", "technology", {"size" => 1})

            objects = expect_paginated_response(request, 1, true)
            # returns most recent post first
            object_data = objects.first.as_h
            expect(object_data["uri"]).to eq("ktistec://objects/#{post2.id}")
            expect(object_data["external_url"]).to eq(post2.iri)
            expect(object_data["internal_url"]).to eq("#{Ktistec.host}/remote/objects/#{post2.id}")
            expect(object_data["type"]).to eq("Object")
            expect(object_data["attributed_to"]).to eq("ktistec://actors/#{post2.attributed_to.id}")
            expect(object_data["content"]).to eq("Another #technology post")
            expect(object_data["published"]).not_to be_nil
          end
        end
      end

      context "with a mention collection" do
        let_create!(
          :object,
          named: mentioned_post,
          attributed_to: account.actor,
          content: "Hey @testuser@example.com check this out!",
          published: Time.utc(2024, 1, 1, 10, 0, 0),
        )
        let_create!(
          :mention,
          named: nil,
          name: "testuser@example.com",
          subject: mentioned_post,
        )

        it "returns mention objects for valid mention" do
          request = paginate_mention_request("paginate-mention-1", "testuser@example.com")

          objects = expect_paginated_response(request, 1, false)

          expect(objects.size).to eq(1)
          object_data = objects.first.as_h
          expect(object_data["uri"]).to eq("ktistec://objects/#{mentioned_post.id}")
          expect(object_data["external_url"]).to eq(mentioned_post.iri)
          expect(object_data["internal_url"]).to eq("#{Ktistec.host}/remote/objects/#{mentioned_post.id}")
          expect(object_data["type"]).to eq("Object")
          expect(object_data["attributed_to"]).to eq("ktistec://actors/#{mentioned_post.attributed_to.id}")
          expect(object_data["content"]).to eq("Hey @testuser@example.com check this out!")
          expect(object_data["published"]).not_to be_nil
        end

        it "returns empty result for non-existent mention" do
          request = paginate_mention_request("paginate-mention-2", "nonexistent@example.com")

          objects = expect_paginated_response(request, 0, false)
          expect(objects.size).to eq(0)
        end

        context "and a second object" do
          let_create!(
            :object,
            named: post2,
            attributed_to: account.actor,
            content: "Another post mentioning @testuser@example.com",
            published: Time.utc(2024, 1, 2, 10, 0, 0),
          )
          let_create!(
            :mention,
            named: nil,
            name: "testuser@example.com",
            subject: post2,
          )

          it "supports pagination for mention collections" do
            request = paginate_mention_request("paginate-mention-3", "testuser@example.com", {"size" => 1})

            objects = expect_paginated_response(request, 1, true)
            # returns most recent post first
            object_data = objects.first.as_h
            expect(object_data["uri"]).to eq("ktistec://objects/#{post2.id}")
            expect(object_data["external_url"]).to eq(post2.iri)
            expect(object_data["internal_url"]).to eq("#{Ktistec.host}/remote/objects/#{post2.id}")
            expect(object_data["type"]).to eq("Object")
            expect(object_data["attributed_to"]).to eq("ktistec://actors/#{post2.attributed_to.id}")
            expect(object_data["content"]).to eq("Another post mentioning @testuser@example.com")
            expect(object_data["published"]).not_to be_nil
          end
        end
      end

      context "with a liked object" do
        let_create(:object, named: liked_post, attributed_to: account.actor, published: now)

        it "is empty" do
          request = paginate_likes_request("paginate-likes-1")

          objects = expect_paginated_response(request, 0, false)
          expect(objects).to be_empty
        end

        context "and a like" do
          let_create!(:like, named: nil, actor: account.actor, object: liked_post)

          it "returns liked objects" do
            request = paginate_likes_request("paginate-likes-2")

            objects = expect_paginated_response(request, 1, false)

            expect(objects.size).to eq(1)
            object_data = objects.first.as_h
            expect(object_data["uri"]).to eq("ktistec://objects/#{liked_post.id}")
            expect(object_data["external_url"]).to eq(liked_post.iri)
            expect(object_data["internal_url"]).to eq("#{Ktistec.host}/remote/objects/#{liked_post.id}")
            expect(object_data["type"]).to eq("Object")
            expect(object_data["attributed_to"]).to eq("ktistec://actors/#{liked_post.attributed_to.id}")
            expect(object_data["published"]).not_to be_nil
          end

          context "and another liked object" do
            let_create(:object, named: post, attributed_to: account.actor)
            let_create!(:like, named: nil, actor: account.actor, object: post)

            it "supports pagination for likes collection" do
              request = paginate_likes_request("paginate-likes-3", {"size" => 1})

              objects = expect_paginated_response(request, 1, true)
              # returns most recent like first
              object_data = objects.first.as_h
              expect(object_data["uri"]).to eq("ktistec://objects/#{post.id}")
            end
          end
        end
      end

      context "with a disliked object" do
        let_create(:object, named: disliked_post, attributed_to: account.actor, published: Time.utc)

        it "is empty" do
          request = paginate_dislikes_request("paginate-dislikes-1")

          objects = expect_paginated_response(request, 0, false)
          expect(objects).to be_empty
        end

        context "and a dislike" do
          let_create!(:dislike, named: nil, actor: account.actor, object: disliked_post)

          it "returns disliked objects" do
            request = paginate_dislikes_request("paginate-dislikes-2")

            objects = expect_paginated_response(request, 1, false)

            expect(objects.size).to eq(1)
            object_data = objects.first.as_h
            expect(object_data["uri"]).to eq("ktistec://objects/#{disliked_post.id}")
            expect(object_data["external_url"]).to eq(disliked_post.iri)
            expect(object_data["internal_url"]).to eq("#{Ktistec.host}/remote/objects/#{disliked_post.id}")
            expect(object_data["type"]).to eq("Object")
            expect(object_data["attributed_to"]).to eq("ktistec://actors/#{disliked_post.attributed_to.id}")
            expect(object_data["published"]).not_to be_nil
          end

          context "and another disliked object" do
            let_create(:object, named: post, attributed_to: account.actor)
            let_create!(:dislike, named: nil, actor: account.actor, object: post)

            it "supports pagination for dislikes collection" do
              request = paginate_dislikes_request("paginate-dislikes-3", {"size" => 1})

              objects = expect_paginated_response(request, 1, true)
              # returns most recent dislike first
              object_data = objects.first.as_h
              expect(object_data["uri"]).to eq("ktistec://objects/#{post.id}")
            end
          end
        end
      end

      context "with an announced object" do
        let_create(:object, named: announced_post, attributed_to: account.actor, published: now)

        it "is empty" do
          request = paginate_announces_request("paginate-announces-1")

          objects = expect_paginated_response(request, 0, false)
          expect(objects).to be_empty
        end

        context "and an announce" do
          let_create!(:announce, named: nil, actor: account.actor, object: announced_post)

          it "returns announced objects" do
            request = paginate_announces_request("paginate-announces-2")

            objects = expect_paginated_response(request, 1, false)

            expect(objects.size).to eq(1)
            object_data = objects.first.as_h
            expect(object_data["uri"]).to eq("ktistec://objects/#{announced_post.id}")
            expect(object_data["external_url"]).to eq(announced_post.iri)
            expect(object_data["internal_url"]).to eq("#{Ktistec.host}/remote/objects/#{announced_post.id}")
            expect(object_data["type"]).to eq("Object")
            expect(object_data["attributed_to"]).to eq("ktistec://actors/#{announced_post.attributed_to.id}")
            expect(object_data["published"]).not_to be_nil
          end

          context "and another announced object" do
            let_create(:object, named: post, attributed_to: account.actor)
            let_create!(:announce, named: nil, actor: account.actor, object: post)

            it "supports pagination for announces collection" do
              request = paginate_announces_request("paginate-announces-3", {"size" => 1})

              objects = expect_paginated_response(request, 1, true)
              # returns most recent announce first
              object_data = objects.first.as_h
              expect(object_data["uri"]).to eq("ktistec://objects/#{post.id}")
            end
          end
        end
      end

      context "for followers" do
        let_create(:actor, named: follower)

        it "is empty given no followers" do
          request = paginate_followers_request("paginate-followers-1")

          objects = expect_paginated_response(request, 0, false)
          expect(objects).to be_empty
        end

        context "with a follower" do
          let_create!(:follow_relationship, named: nil, actor: follower, object: account.actor, confirmed: true)

          it "returns follower relationships" do
            request = paginate_followers_request("paginate-followers-2")

            objects = expect_paginated_response(request, 1, false)

            relationship = objects.first.as_h
            expect(relationship["actor"]).to eq("ktistec://actors/#{follower.id}")
            expect(relationship["confirmed"]).to eq(true)
          end

          context "and an unconfirmed follower" do
            let_create(:actor, named: unconfirmed_follower)
            let_create!(:follow_relationship, named: nil, actor: unconfirmed_follower, object: account.actor, confirmed: false)

            it "includes both confirmed and unconfirmed followers" do
              request = paginate_followers_request("paginate-followers-3")

              objects = expect_paginated_response(request, 2, false)

              unconfirmed_relationship = objects[0].as_h
              expect(unconfirmed_relationship["actor"]).to eq("ktistec://actors/#{unconfirmed_follower.id}")
              expect(unconfirmed_relationship["confirmed"]).to eq(false)

              confirmed_relationship = objects[1].as_h
              expect(confirmed_relationship["actor"]).to eq("ktistec://actors/#{follower.id}")
              expect(confirmed_relationship["confirmed"]).to eq(true)
            end

            it "supports pagination for followers collection" do
              request = paginate_followers_request("paginate-followers-4", {"size" => 1})

              objects = expect_paginated_response(request, 1, true)

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

          objects = expect_paginated_response(request, 0, false)
          expect(objects).to be_empty
        end

        context "with following" do
          let_create!(:follow_relationship, named: nil, actor: account.actor, object: followed_actor, confirmed: true)

          it "returns following relationships" do
            request = paginate_following_request("paginate-following-2")

            objects = expect_paginated_response(request, 1, false)

            relationship = objects.first.as_h
            expect(relationship["actor"]).to eq("ktistec://actors/#{followed_actor.id}")
            expect(relationship["confirmed"]).to eq(true)
          end

          context "and an unconfirmed following" do
            let_create(:actor, named: unconfirmed_followed)
            let_create!(:follow_relationship, named: nil, actor: account.actor, object: unconfirmed_followed, confirmed: false)

            it "includes both confirmed and unconfirmed following" do
              request = paginate_following_request("paginate-following-3")

              objects = expect_paginated_response(request, 2, false)

              unconfirmed_relationship = objects[0].as_h
              expect(unconfirmed_relationship["actor"]).to eq("ktistec://actors/#{unconfirmed_followed.id}")
              expect(unconfirmed_relationship["confirmed"]).to eq(false)

              confirmed_relationship = objects[1].as_h
              expect(confirmed_relationship["actor"]).to eq("ktistec://actors/#{followed_actor.id}")
              expect(confirmed_relationship["confirmed"]).to eq(true)
            end

            it "supports pagination for following collection" do
              request = paginate_following_request("paginate-following-4", {"size" => 1})

              objects = expect_paginated_response(request, 1, true)

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
        JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "#{id}", "method": "tools/call", "params": {"name": "count_collection_since", "arguments": {#{args_json}}}}|)
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

      def count_announces_since_request(id, args = {} of String => String | Int32)
        count_since_request(id, "announces", args)
      end

      def count_followers_since_request(id, args = {} of String => String | Int32)
        count_since_request(id, "followers", args)
      end

      def count_following_since_request(id, args = {} of String => String | Int32)
        count_since_request(id, "following", args)
      end

      def expect_count_response(request, expected_count)
        response = described_class.handle_tools_call(request, account)
        content = response["content"].as_a
        expect(content.size).to eq(1)
        data = JSON.parse(content.first["text"].as_s)
        expect(Time.parse_rfc3339(data["counted_at"].as_s)).to be_within(5.seconds).of(now)
        expect(data["count"]).to eq(expected_count)
      end

      it "returns error for invalid collection name" do
        request = count_timeline_since_request("count-8", {"name" => "does_not_exist", "since" => "2024-01-01T00:00:00Z"})
        expect { described_class.handle_tools_call(request, account) }.to raise_error(MCPError, "`does_not_exist` unsupported")
      end

      it "returns zero count for empty timeline" do
        request = count_timeline_since_request("count-10", {"since" => "2024-01-01T00:00:00Z"})
        expect { expect_count_response(request, 0) }.not_to raise_error
      end

      context "with notifications" do
        let_create(:object, named: object1)
        let_create(:object, named: object2)
        let_create(:object, named: object3)
        let_create(:create, named: create1, actor: account.actor, object: object1)
        let_create(:create, named: create2, actor: account.actor, object: object2)
        let_create(:create, named: create3, actor: account.actor, object: object3)

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

          expect_count_response(request, 2)
        end

        it "returns zero count when no notifications match timestamp" do
          since_time = (create3.created_at + 1.hour).to_rfc3339
          request = count_notifications_since_request("count-notifications-2", {"since" => since_time})

          expect_count_response(request, 0)
        end

        it "returns total count when timestamp is before all notifications" do
          since_time = (create1.created_at - 1.hour).to_rfc3339
          request = count_notifications_since_request("count-notifications-3", {"since" => since_time})

          expect_count_response(request, 3)
        end
      end

      context "with objects in timeline" do
        let_create(:object, named: object1, attributed_to: account.actor)
        let_create(:object, named: object2, attributed_to: account.actor)
        let_create(:object, named: object3, attributed_to: account.actor)

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

          expect_count_response(request, 2)
        end

        it "returns zero count when no objects match timestamp" do
          since_time = (object3.created_at + 1.hour).to_rfc3339
          request = count_timeline_since_request("count-12", {"since" => since_time})

          expect_count_response(request, 0)
        end

        it "returns total count when timestamp is before all objects" do
          since_time = (object1.created_at - 1.hour).to_rfc3339
          request = count_timeline_since_request("count-13", {"since" => since_time})

          expect_count_response(request, 3)
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

          expect_count_response(request, 2)
        end

        it "returns zero count when no posts match timestamp" do
          since_time = (object3.created_at + 1.hour).to_rfc3339
          request = count_posts_since_request("count-posts-2", {"since" => since_time})

          expect_count_response(request, 0)
        end

        it "returns total count when timestamp is before all posts" do
          since_time = (object1.created_at - 1.hour).to_rfc3339
          request = count_posts_since_request("count-posts-3", {"since" => since_time})

          expect_count_response(request, 3)
        end
      end

      context "with draft objects for actor" do
        let_create!(:object, named: object1, attributed_to: account.actor, published: nil)
        let_create!(:object, named: object2, attributed_to: account.actor, published: nil)
        let_create!(:object, named: object3, attributed_to: account.actor, published: nil)

        it "returns count of drafts since given timestamp" do
          since_time = (object2.created_at - 1.second).to_rfc3339
          request = count_drafts_since_request("count-drafts-1", {"since" => since_time})

          expect_count_response(request, 2)
        end

        it "returns zero count when no drafts match timestamp" do
          since_time = (object3.created_at + 1.hour).to_rfc3339
          request = count_drafts_since_request("count-drafts-2", {"since" => since_time})

          expect_count_response(request, 0)
        end

        it "returns total count when timestamp is before all drafts" do
          since_time = (object1.created_at - 1.hour).to_rfc3339
          request = count_drafts_since_request("count-drafts-3", {"since" => since_time})

          expect_count_response(request, 3)
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
          subject: tagged_post,
          created_at: Time.utc(2024, 1, 1, 10, 0, 0)
        )

        it "returns count for valid hashtag" do
          request = count_hashtag_since_request("count-hashtag-1", "testhashtag", {"since" => "2024-01-01T00:00:00Z"})

          expect_count_response(request, 1)
        end

        it "returns 0 for non-existent hashtag" do
          request = count_hashtag_since_request("count-hashtag-2", "nonexistent", {"since" => "2024-01-01T00:00:00Z"})

          expect_count_response(request, 0)
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
          subject: mentioned_post,
          created_at: Time.utc(2024, 1, 1, 10, 0, 0)
        )

        it "returns count for valid mention" do
          request = count_mention_since_request("count-mention-1", "testuser@example.com", {"since" => "2024-01-01T00:00:00Z"})

          expect_count_response(request, 1)
        end

        it "returns 0 for non-existent mention" do
          request = count_mention_since_request("count-mention-2", "nonexistent@example.com", {"since" => "2024-01-01T00:00:00Z"})

          expect_count_response(request, 0)
        end
      end

      context "with likes collection" do
        let_create!(
          :like,
          named: nil,
          actor: account.actor,
          created_at: Time.utc(2024, 1, 1, 10, 0, 0)
        )
        let_create!(
          :like,
          named: nil,
          actor: account.actor,
          created_at: Time.utc(2024, 1, 1, 12, 0, 0)
        )

        it "returns count for likes collection" do
          request = count_likes_since_request("count-likes-1", {"since" => "2024-01-01T09:00:00Z"})

          expect_count_response(request, 2)
        end

        it "returns count for likes collection" do
          request = count_likes_since_request("count-likes-2", {"since" => "2024-01-01T11:00:00Z"})

          expect_count_response(request, 1)
        end
      end

      context "with announces collection" do
        let_create!(
          :announce,
          named: nil,
          actor: account.actor,
          created_at: Time.utc(2024, 1, 1, 10, 0, 0)
        )
        let_create!(
          :announce,
          named: nil,
          actor: account.actor,
          created_at: Time.utc(2024, 1, 1, 12, 0, 0)
        )

        it "returns count for announces collection" do
          request = count_announces_since_request("count-announces-1", {"since" => "2024-01-01T09:00:00Z"})

          expect_count_response(request, 2)
        end

        it "returns count respecting since timestamp" do
          request = count_announces_since_request("count-announces-2", {"since" => "2024-01-01T11:00:00Z"})

          expect_count_response(request, 1)
        end
      end

      context "with followers collection" do
        it "returns zero count" do
          request = count_followers_since_request("count-followers-1", {"since" => "2024-01-01T00:00:00Z"})

          expect_count_response(request, 0)
        end

        context "with followers" do
          let_create(:actor, named: follower)
          let_create!(:follow_relationship, actor: follower, object: account.actor, created_at: Time.utc(2024, 1, 2))

          it "returns count of followers" do
            request = count_followers_since_request("count-followers-2", {"since" => "2024-01-01T00:00:00Z"})

            expect_count_response(request, 1)
          end

          it "returns zero count" do
            request = count_followers_since_request("count-followers-3", {"since" => "2024-01-03T00:00:00Z"})

            expect_count_response(request, 0)
          end
        end
      end

      context "with following collection" do
        it "returns zero count" do
          request = count_following_since_request("count-following-1", {"since" => "2024-01-01T00:00:00Z"})

          expect_count_response(request, 0)
        end

        context "with following" do
          let_create(:actor, named: followed_actor)
          let_create!(:follow_relationship, actor: account.actor, object: followed_actor, created_at: Time.utc(2024, 1, 2))

          it "returns count of following" do
            request = count_following_since_request("count-following-2", {"since" => "2024-01-01T00:00:00Z"})

            expect_count_response(request, 1)
          end

          it "returns zero count" do
            request = count_following_since_request("count-following-3", {"since" => "2024-01-03T00:00:00Z"})

            expect_count_response(request, 0)
          end
        end
      end
    end

    context "with read_resources tool" do
      let_create(:actor, named: test_actor)
      let_create(:object, named: test_object, attributed_to: account.actor)

      private def read_resources_request(id, uris)
        json_uris = uris.map(&.inspect).join(", ")
        JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "#{id}", "method": "tools/call", "params": {"name": "read_resources", "arguments": {"uris": [#{json_uris}]}}}|)
      end

      def expect_resources_response(request, expected_size)
        response = described_class.handle_tools_call(request, account)
        content = response["content"].as_a
        expect(content.size).to eq(1)
        data = JSON.parse(content.first["text"].as_s)
        expect(data["resources"].as_a.size).to eq(expected_size)
        data["resources"].as_a
      end

      it "reads single actor resource" do
        request = read_resources_request("read-1", ["ktistec://actors/#{test_actor.id}"])

        resources = expect_resources_response(request, 1)

        expect(resources[0]["uri"]).to eq("ktistec://actors/#{test_actor.id}")
      end

      it "reads single object resource" do
        request = read_resources_request("read-2", ["ktistec://objects/#{test_object.id}"])

        resources = expect_resources_response(request, 1)
        expect(resources[0]["uri"]).to eq("ktistec://objects/#{test_object.id}")
      end

      it "reads information resource" do
        request = read_resources_request("read-3", ["ktistec://information"])

        resources = expect_resources_response(request, 1)
        expect(resources[0]["uri"]).to eq("ktistec://information")
      end

      it "reads multiple different resource types" do
        request = read_resources_request("read-4", ["ktistec://actors/#{test_actor.id}", "ktistec://objects/#{test_object.id}", "ktistec://information"])

        resources = expect_resources_response(request, 3)
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

          resources = expect_resources_response(request, 3)
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

          resources = expect_resources_response(request, 3)
          uris = resources.map(&.["uri"].as_s)
          expect(uris).to contain("ktistec://objects/#{test_object.id}")
          expect(uris).to contain("ktistec://objects/#{test_object2.id}")
          expect(uris).to contain("ktistec://objects/#{test_object3.id}")
        end
      end

      it "handles invalid resource URI" do
        request = read_resources_request("read-7", ["ktistec://invalid/123"])

        expect { described_class.handle_tools_call(request, account) }.to raise_error(MCPError, /Unsupported URI scheme: ktistec:\/\/invalid\/123/)
      end
    end
  end
end
