require "../spec_helper"

Spectator.describe ActivityPub do
  describe ".from_json_ld" do
    it "instantiates the correct subclass" do
      expect(described_class.from_json_ld(%q[{"@type":"Person"}])).to be_a(ActivityPub::Actor::Person)
      expect(described_class.from_json_ld(%q[{"@type":"Collection"}])).to be_a(ActivityPub::Collection)
    end
  end
end
