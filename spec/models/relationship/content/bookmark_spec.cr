require "../../../../src/models/relationship/content/bookmark"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Relationship::Content::Bookmark do
  setup_spec

  let(options) do
    {
      from_iri: Factory.create(:actor).iri,
      to_iri: Factory.create(:object).iri
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
  end

  context "uniqueness" do
    it "enforces one bookmark per actor/object pair" do
      described_class.new(**options).save
      bookmark = described_class.new(**options)
      expect(bookmark.valid?).to be_false
      expect(bookmark.errors.keys).to contain("relationship")
    end
  end
end
