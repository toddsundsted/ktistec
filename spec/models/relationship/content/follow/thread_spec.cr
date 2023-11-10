require "../../../../../src/models/relationship/content/follow/thread"

require "../../../../spec_helper/base"
require "../../../../spec_helper/factory"

Spectator.describe Relationship::Content::Follow::Thread do
  setup_spec

  let(options) do
    {
      from_iri: Factory.create(:actor).iri,
      to_iri: "https://#{random_string}"
    }
  end

  context "validation" do
    it "rejects missing actor" do
      new_relationship = described_class.new(**options.merge({from_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("actor")
    end

    it "rejects blank thread" do
      new_relationship = described_class.new(**options.merge({to_iri: ""}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("thread")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  describe "#thread=" do
    subject { described_class.new(**options) }

    it "sets to_iri" do
      expect{subject.assign(thread: "https://thread")}.to change{subject.to_iri}
    end
  end

  describe "#thread" do
    subject { described_class.new(**options) }

    it "gets to_iri" do
      expect(subject.thread).to eq(subject.to_iri)
    end
  end
end
