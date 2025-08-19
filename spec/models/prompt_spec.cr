require "file_utils"

require "../../src/models/prompt"

require "../spec_helper/base"

class Prompt
  def self.reset!
    @@cached_prompts = [] of Prompt
    @@cache_timestamp = Time::UNIX_EPOCH
  end

  @@temp_dir = File.join(File.tempname, "prompts", "test")

  # discard private visibility and create temporary directory for testing
  def self.default_prompts_dir : String
    Dir.mkdir_p(@@temp_dir) unless Dir.exists?(@@temp_dir)
    @@temp_dir
  end
end

Spectator.describe Prompt do
  def make_prompt(name)
    yaml = %Q({name: "#{name}", arguments: [], messages: []})
    File.write(File.join(Prompt.default_prompts_dir, "#{name}.yml"), yaml)
  end

  before_each do
    Prompt.reset!
  end

  after_each do
    FileUtils.rm_rf(Prompt.default_prompts_dir)
  end

  describe ".all" do
    it "loads prompts" do
      make_prompt("test_prompt")

      prompts = Prompt.all
      expect(prompts.size).to eq(1)

      test_prompt = prompts.first
      expect(test_prompt.name).to eq("test_prompt")
    end

    it "loads new prompts" do
      make_prompt("test_prompt")

      prompts = Prompt.all
      expect(prompts.size).to eq(1)

      make_prompt("new_prompt")

      prompts = Prompt.all
      expect(prompts.size).to eq(2)

      new_prompt = prompts.last
      expect(new_prompt.name).to eq("new_prompt")
    end

    it "caches prompts" do
      make_prompt("test_prompt")

      first_prompts = Prompt.all
      second_prompts = Prompt.all

      expect(second_prompts).to be(first_prompts)
      expect(second_prompts.size).to be(first_prompts.size)
      expect(second_prompts.last).to be(first_prompts.last)
    end

    it "handles no prompts" do
      prompts = Prompt.all
      expect(prompts.size).to eq(0)
    end
  end

  describe ".substitute" do
    it "raises error for missing variables" do
      template = "Hello {{unknown}} and {{missing}}"
      arguments = {} of String => String
      context = {} of String => String

      expect { Prompt.substitute(template, arguments, context) }.to raise_error(Exception, /unknown, missing/)
    end

    it "substitutes variables from arguments and context" do
      template = "Hello {{name}}, you have {{count}} messages in your {{collection}}"
      arguments = {"name" => "Alice", "count" => "5"}
      context = {"collection" => "inbox"}

      result = Prompt.substitute(template, arguments, context)
      expect(result).to eq("Hello Alice, you have 5 messages in your inbox")
    end

    it "allows arguments to override context variables" do
      template = "Hello {{name}}"
      arguments = {"name" => "Alice"}
      context = {"name" => "Bob"}

      result = Prompt.substitute(template, arguments, context)
      expect(result).to eq("Hello Alice")
    end

    it "handles escaped braces" do
      template = "Use \\{{variable}} for substitution"
      arguments = {} of String => String
      context = {} of String => String

      result = Prompt.substitute(template, arguments, context)
      expect(result).to eq("Use {{variable}} for substitution")
    end

    it "permits escaped closing braces" do
      template = "Use \\{{variable\\}} for substitution"
      arguments = {} of String => String
      context = {} of String => String

      result = Prompt.substitute(template, arguments, context)
      expect(result).to eq("Use {{variable}} for substitution")
    end
  end

  describe ".from_yaml and #to_yaml" do
    it "can deserialize and serialize a prompt" do
      yaml = <<-YAML
        name: "test_prompt"
        title: "Test Prompt"
        description: "A simple test prompt"
        arguments:
          - name: "since"
            title: "Since When"
            description: "Cutoff timestamp"
            required: true
        messages:
          - role: "user"
            content:
              type: "text"
              text: "Test!"
      YAML

      # deserialization
      prompt = Prompt.from_yaml(yaml)
      expect(prompt.name).to eq("test_prompt")
      expect(prompt.title).to eq("Test Prompt")
      expect(prompt.description).to eq("A simple test prompt")

      expect(prompt.arguments.size).to eq(1)
      expect(prompt.arguments.first.name).to eq("since")
      expect(prompt.arguments.first.title).to eq("Since When")
      expect(prompt.arguments.first.description).to eq("Cutoff timestamp")
      expect(prompt.arguments.first.required).to be_true

      expect(prompt.messages.size).to eq(1)
      expect(prompt.messages.first.role).to eq(Prompt::Role::User)
      expect(prompt.messages.first.content.type).to eq(Prompt::ContentType::Text)
      expect(prompt.messages.first.content.text).to eq("Test!")

      # serialization
      yaml = prompt.to_yaml
      expect(yaml).to be_a(String)
      expect(yaml).to contain("name: test_prompt")
      expect(yaml).to contain("title: Test Prompt")
      expect(yaml).to contain("description: A simple test prompt")
      expect(yaml).to contain("name: since")
      expect(yaml).to contain("title: Since When")
      expect(yaml).to contain("required: true")
      expect(yaml).to contain("role: user")
      expect(yaml).to contain("type: text")
      expect(yaml).to contain("text: Test!")
    end
  end
end
