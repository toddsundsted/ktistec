require "spectator"
require "yaml"

require "../../src/ktistec/version"

Spectator.describe Ktistec do
  describe "::VERSION" do
    it "should return the version" do
      version = YAML.parse(File.read(File.join(__DIR__, "..", "..", "shard.yml")))["version"].as_s
      expect(Ktistec::VERSION).to eq(version)
    end
  end
end
