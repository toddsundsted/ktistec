require "file_utils"

require "../../src/mcp/prompts"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe MCP::Prompts do
  setup_spec

  let!(account) { register }

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

  MCP::Prompts.def_prompt("test_prompt", "Test Prompt", "A test prompt for `def_prompt` macro testing", [
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

  context "test_prompt validation" do
    it "validates and extracts arguments" do
      arguments = JSON::Any.new({
        "topic" => JSON::Any.new("ActivityPub federation"),
        "style" => JSON::Any.new("technical"),
      })

      result = described_class.handle_prompt_test_prompt(arguments, account)

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

      result = described_class.handle_prompt_test_prompt(arguments, account)

      message = result.as_a[0]
      content = message["content"]
      expect(content["text"].as_s).to eq("Please discuss ActivityPub protocol.")
    end

    it "validates required arguments" do
      arguments = JSON::Any.new({} of String => JSON::Any)

      expect { described_class.handle_prompt_test_prompt(arguments, account) }.to raise_error(MCPError, /Missing topic/)
    end
  end

  context "with prompts/list request" do
    let(prompts_list_request) do
      JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "prompts-1", "method": "prompts/list"}|)
    end

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
      response = described_class.handle_prompts_list(prompts_list_request)

      prompts = response["prompts"].as_a
      expect(prompts.size).to eq(2)  # test_prompt & whats_new

      names = prompts.map(&.["name"].as_s)
      expect(names).to contain("test_prompt", "whats_new")
    end

    context "test_prompt" do
      let(test_prompt) do
        response = described_class.handle_prompts_list(prompts_list_request)

        prompts = response["prompts"].as_a
        prompts.find! { |p| p["name"].as_s == "test_prompt" }
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
        response = described_class.handle_prompts_list(prompts_list_request)

        prompts = response["prompts"].as_a
        prompts.find! { |p| p["name"].as_s == "whats_new" }
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

  context "with prompts/get request" do
    let(prompts_get_request) do
      JSON::RPC::Request.from_json(%Q|{"jsonrpc": "2.0", "id": "prompt-get-1", "method": "prompts/get", "params": {"name": "nonexistent_prompt"}}|)
    end

    it "returns protocol error for invalid prompt name" do
      expect { described_class.handle_prompts_get(prompts_get_request, account) }.to raise_error(MCPError, /Invalid prompt name/)
    end
  end
end
