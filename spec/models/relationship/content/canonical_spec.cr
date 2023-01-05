require "../../../../src/models/relationship/content/canonical"

require "../../../spec_helper/base"

Spectator.describe Relationship::Content::Canonical do
  setup_spec

  let(options) do
    {
      from_iri: "/canonical/iri",
      to_iri: "/original/iri"
    }
  end

  before_all do
    Kemal::RouteHandler::INSTANCE.add_route("GET", "/original/iri") { }
  end

  context "validation" do
    it "rejects relative from_iri" do
      new_relationship = described_class.new(**options.merge({from_iri: "relative"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors).to have_key("from_iri")
      expect(new_relationship.errors).to have_value(["must be absolute"])
    end

    it "rejects relative to_iri" do
      new_relationship = described_class.new(**options.merge({to_iri: "relative"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors).to have_key("to_iri")
      expect(new_relationship.errors).to have_value(["must be absolute"])
    end

    context "given a route" do
      it "rejects a from_iri that routes" do
        new_relationship = described_class.new(**options.merge({from_iri: "/original/iri"}))
        expect(new_relationship.valid?).to be_false
        expect(new_relationship.errors).to have_key("from_iri")
        expect(new_relationship.errors).to have_value(["must not match an existing route"])
      end

      it "rejects a to_iri that does not route" do
        new_relationship = described_class.new(**options.merge({to_iri: "/does/not/route"}))
        expect(new_relationship.valid?).to be_false
        expect(new_relationship.errors).to have_key("to_iri")
        expect(new_relationship.errors).to have_value(["must match an existing route"])
      end
    end

    context "given an exiting relationship" do
      before_each { described_class.new(**options).save }

      it "rejects existing from_iri" do
        new_relationship = described_class.new(**options.merge({to_iri: "/okay"}))
        expect(new_relationship.valid?).to be_false
        expect(new_relationship.errors).to have_key("from_iri")
        expect(new_relationship.errors).to have_value(["must be unique"])
      end

      it "rejects existing to_iri" do
        new_relationship = described_class.new(**options.merge({from_iri: "/okay"}))
        expect(new_relationship.valid?).to be_false
        expect(new_relationship.errors).to have_key("to_iri")
        expect(new_relationship.errors).to have_value(["must be unique"])
      end
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end
end
