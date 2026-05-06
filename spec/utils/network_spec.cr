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

    it "resolves a profile-style URL" do
      expect(described_class.resolve("https://foo.bar/@baz")).to eq("https://foo.bar/actors/baz")
    end

    it "tolerates a trailing slash on a profile-style URL" do
      expect(described_class.resolve("https://foo.bar/@baz/")).to eq("https://foo.bar/actors/baz")
    end

    it "leaves a profile-style URL with a path unchanged" do
      expect(described_class.resolve("https://foo.bar/@baz/123")).to eq("https://foo.bar/@baz/123")
    end

    it "leaves a profile-style URL with a path unchanged" do
      expect(described_class.resolve("https://foo.bar/quux/@baz")).to eq("https://foo.bar/quux/@baz")
    end
  end
end
