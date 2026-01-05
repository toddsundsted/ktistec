require "../../../../../../src/models/relationship/content/notification/poll/expiry"

require "../../../../../spec_helper/base"
require "../../../../../spec_helper/factory"

Spectator.describe Relationship::Content::Notification::Poll::Expiry do
  setup_spec

  let_create(:actor, named: :owner)
  let_create(:question)

  let(options) do
    {
      owner: owner,
      question: question
    }
  end

  context "validation" do
    it "rejects missing owner" do
      new_relationship = described_class.new(from_iri: "", question: question)
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("owner")
    end

    it "rejects missing question" do
      new_relationship = described_class.new(owner: owner, to_iri: "")
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("question")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end
end
