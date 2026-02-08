require "../../src/utils/paths"

require "../spec_helper/base"

Spectator.describe Utils::Paths do
  setup_spec

  describe ".path_id_from_iri" do
    it "returns the last path segment" do
      expect(Utils::Paths.path_id_from_iri("https://test.test/objects/abc123")).to eq("abc123")
    end

    it "strips trailing slash" do
      expect(Utils::Paths.path_id_from_iri("https://test.test/objects/abc123/")).to eq("abc123")
    end

    it "returns the input" do
      expect(Utils::Paths.path_id_from_iri("abc123")).to eq("abc123")
    end
  end
end
