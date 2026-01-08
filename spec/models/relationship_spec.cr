require "../../src/models/relationship"

require "../spec_helper/base"

class FooBarRelationship < Relationship
  validates(from_iri) { "missing actor" if from_iri =~ /missing/ }
  validates(to_iri) { "missing actor" if to_iri =~ /missing/ }
end

Spectator.describe Relationship do
  setup_spec

  context "validations" do
    let(options) do
      {
        from_iri: "https://test.test/#{random_string}",
        to_iri:   "https://test.test/#{random_string}",
      }
    end

    it "runs validation and rejects" do
      new_relationship = FooBarRelationship.new(**options.merge({from_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("from_iri")
    end

    it "runs validation and rejects" do
      new_relationship = FooBarRelationship.new(**options.merge({to_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("to_iri")
    end

    it "rejects duplicates" do
      described_class.new(**options).save
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("relationship")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end
end
