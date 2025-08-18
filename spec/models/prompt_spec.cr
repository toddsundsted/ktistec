require "../../src/models/prompt"

require "../spec_helper/base"

Spectator.describe Prompt do
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
