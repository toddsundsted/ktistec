require "../../../../../src/models/relationship/content/follow/hashtag"

require "../../../../spec_helper/base"
require "../../../../spec_helper/factory"

Spectator.describe Relationship::Content::Follow::Hashtag do
  setup_spec

  let(options) do
    {
      from_iri: Factory.create(:actor).iri,
      to_iri: random_string
    }
  end

  context "validation" do
    it "rejects missing actor" do
      new_relationship = described_class.new(**options.merge({from_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("actor")
    end

    it "rejects blank name" do
      new_relationship = described_class.new(**options.merge({to_iri: ""}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("name")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  describe "#name=" do
    subject { described_class.new(**options) }

    it "sets to_iri" do
      expect{subject.assign(name: "tag")}.to change{subject.to_iri}
    end
  end

  describe "#name" do
    subject { described_class.new(**options) }

    it "gets to_iri" do
      expect(subject.name).to eq(subject.to_iri)
    end
  end

  describe ".find_or_new" do
    it "instantiates a new follow" do
      expect(described_class.find_or_new(**options).new_record?).to be_true
    end

    context "given an existing follow" do
      let!(existing) { described_class.new(**options).save }

      it "finds the existing follow" do
        expect(described_class.find_or_new(**options)).to eq(existing)
      end
    end
  end
end
