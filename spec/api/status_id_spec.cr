require "../../src/api/status_id"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe API::StatusID do
  setup_spec

  let_create(:object)
  let_create(:announce, object: object)

  describe ".from_object" do
    subject { described_class.from_object(object) }

    it "encodes the object id" do
      expect(subject.to_s).to eq(object.id!.to_s)
    end
  end

  describe ".from_announce" do
    subject { described_class.from_announce(announce) }

    it "encodes an id distinct from the reblogged object id" do
      expect(subject.to_s).not_to eq(object.id!.to_s)
    end
  end

  describe ".decode" do
    it "round-trips an object id" do
      expect(described_class.decode(described_class.from_object(object).to_s)).to eq({:object, object.id!})
    end

    it "round-trips an announce id" do
      expect(described_class.decode(described_class.from_announce(announce).to_s)).to eq({:announce, announce.id!})
    end

    it "returns nil for non-numeric input" do
      expect(described_class.decode("abc")).to be_nil
    end

    it "returns nil for negative input" do
      expect(described_class.decode("-1")).to be_nil
    end

    it "returns nil for zero" do
      expect(described_class.decode("0")).to be_nil
    end
  end

  describe "#to_json" do
    subject { described_class.from_object(object) }

    it "serializes as a JSON string" do
      expect(subject.to_json).to eq(%Q("#{object.id!}"))
    end
  end
end
