require "../../../../src/models/relationship/content/pin"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Relationship::Content::Pin do
  setup_spec

  let_create(:object)

  let(options) do
    {
      from_iri: object.attributed_to.iri,
      to_iri:   object.iri,
    }
  end

  context "validation" do
    it "rejects missing actor" do
      new_relationship = described_class.new(**options.merge({from_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("actor")
    end

    it "rejects missing object" do
      new_relationship = described_class.new(**options.merge({to_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("object")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end

    context "given an actor other than attributed to" do
      let_build(:actor)

      it "fails to validate" do
        new_relationship = described_class.new(actor: actor, object: object)
        expect(new_relationship.valid?).to be_false
        expect(new_relationship.errors.keys).to contain("object")
      end
    end
  end

  context "uniqueness" do
    it "enforces one pin per actor/object pair" do
      described_class.new(**options).save
      pin = described_class.new(**options)
      expect(pin.valid?).to be_false
      expect(pin.errors.keys).to contain("relationship")
    end
  end
end
