require "../../../../src/models/relationship/content/inbox"

require "../../../spec_helper/model"

Spectator.describe Relationship::Content::Outbox do
  setup_spec

  let(options) do
    {
      from_iri: ActivityPub::Actor.new(iri: "https://test.test/#{random_string}").save.iri,
      to_iri: ActivityPub::Activity.new(iri: "https://test.test/#{random_string}").save.iri
    }
  end

  context "creation" do
    let(relationship) { described_class.new(**options).save }

    it "creates confirmed relationships by default" do
      expect(relationship.confirmed).to be_true
    end
  end

  context "validation" do
    it "rejects missing owner" do
      new_relationship = described_class.new(**options.merge({from_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("owner")
    end

    it "rejects missing activity" do
      new_relationship = described_class.new(**options.merge({to_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("activity")
    end

    it "permits duplicates" do
      described_class.new(**options).save
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end
end
