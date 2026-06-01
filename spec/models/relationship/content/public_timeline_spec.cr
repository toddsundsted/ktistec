require "../../../../src/models/relationship/content/public_timeline"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Relationship::Content::PublicTimeline do
  setup_spec

  let_create(:object, named: to)

  let(options) do
    {
      to_iri: to.iri,
    }
  end

  context "creation" do
    let(relationship) { described_class.new(**options).save }

    it "sets from_iri to the public sentinel" do
      expect(relationship.from_iri).to eq(Ktistec::Constants::PUBLIC)
    end
  end

  context "validation" do
    it "rejects missing object" do
      new_relationship = described_class.new(**options.merge({to_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("object")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end
end
