require "../../src/utils/network"

require "../spec_helper/network"

Spectator.describe Ktistec::Network do
  describe ".resolve" do
    it "returns the IRI" do
      expect(described_class.resolve("https://foo.bar/actors/baz")).to eq("https://foo.bar/actors/baz")
    end

    it "resolves and returns the IRI" do
      expect(described_class.resolve("baz@foo.bar")).to eq("https://foo.bar/actors/baz")
    end

    it "resolves and returns the IRI" do
      expect(described_class.resolve("@baz@foo.bar")).to eq("https://foo.bar/actors/baz")
    end
  end
end
