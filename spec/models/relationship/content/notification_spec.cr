require "../../../../src/models/relationship/content/notification"

require "../../../spec_helper/factory"
require "../../../spec_helper/model"

Spectator.describe Relationship::Content::Notification do
  setup_spec

  let(options) do
    {
      from_iri: Factory.create(:actor).iri,
      to_iri: Factory.create(:activity).iri
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

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end
end
