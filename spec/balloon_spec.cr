require "./spec_helper"
require "yaml"

Spectator.describe Balloon do
  describe "::VERSION" do
    it "should return the version" do
      version = YAML.parse(File.read(File.join(__DIR__, "..", "shard.yml")))["version"].as_s
      expect(Balloon::VERSION).to eq(version)
    end
  end
end
