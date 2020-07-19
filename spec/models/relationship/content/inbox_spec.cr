require "../../../spec_helper"

Spectator.describe Relationship::Content::Inbox do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  let(options) do
    {
      from_iri: ActivityPub::Actor.new(iri: "https://test.test/#{random_string}").save.iri,
      to_iri: ActivityPub::Activity.new(iri: "https://test.test/#{random_string}").save.iri
    }
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
