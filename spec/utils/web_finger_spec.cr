require "spectator"

require "../../src/utils/web_finger"

require "../spec_helper/base"
require "../spec_helper/network"

Spectator.describe Ktistec::WebFinger do
  setup_spec

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

    context "given a self link with a blank href" do
      before_each { described_class.resolve("baz@foo.bar", to: "") }

      pre_condition { expect(described_class.query("acct:baz@foo.bar").link("self").href).to eq("") }

      it "raises an error" do
        expect { described_class.resolve("baz@foo.bar") }.to raise_error(Ktistec::WebFinger::ResultError)
      end
    end
  end
end
