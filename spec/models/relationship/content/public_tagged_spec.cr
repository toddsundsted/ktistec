require "../../../../src/models/relationship/content/public_tagged"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Relationship::Content::PublicTagged do
  setup_spec

  let_create(:object, named: to)

  let(options) do
    {
      from_iri: "https://test.test/tags/foo",
      to_iri:   to.iri,
    }
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
