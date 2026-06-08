require "../../../../../src/models/relationship/content/follow/mention"

require "../../../../spec_helper/base"
require "../../../../spec_helper/factory"

Spectator.describe Relationship::Content::Follow::Mention do
  setup_spec

  let_create(:actor, named: from)

  let(options) do
    {
      from_iri: from.iri,
      to_iri:   "#{random_string}@remote",
    }
  end

  context "validation" do
    it "rejects missing actor" do
      new_relationship = described_class.new(**options.merge({from_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("actor")
    end

    it "rejects blank href" do
      new_relationship = described_class.new(**options.merge({to_iri: ""}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("href")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  describe "#href=" do
    subject { described_class.new(**options) }

    it "sets to_iri" do
      expect { subject.assign(href: "https://remote/actors/mention") }.to change { subject.to_iri }
    end
  end

  describe "#href" do
    subject { described_class.new(**options) }

    it "gets to_iri" do
      expect(subject.href).to eq(subject.to_iri)
    end
  end
end
