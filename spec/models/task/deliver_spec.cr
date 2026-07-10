require "../../../src/models/task/deliver"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/network"

Spectator.describe Task::Deliver do
  setup_spec

  let(sender) do
    register.actor
  end

  let_build(:activity)

  context "validation" do
    let!(options) do
      {source_iri: sender.save.iri, subject_iri: activity.save.iri}
    end

    it "rejects missing sender" do
      new_relationship = described_class.new(**options.merge({source_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("sender")
    end

    it "rejects missing activity" do
      new_relationship = described_class.new(**options.merge({subject_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("activity")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  describe "#sender" do
    before_each do
      sender.save.delete!
      activity.save
    end

    it "resolves a deleted sender" do
      task = described_class.new(source_iri: sender.iri, subject_iri: activity.iri)
      expect(task.sender.iri).to eq(sender.iri)
    end
  end

  subject do
    described_class.new(
      sender: sender,
      activity: activity,
    )
  end

  describe "#recipients" do
    it "persists recipients across save and reload" do
      task = described_class.new(sender: sender.save, activity: activity.save, recipients: ["https://example/recipient"]).save
      expect(described_class.find(task.id).recipients).to eq(["https://example/recipient"])
    end

    it "returns an empty array when no recipients are stored" do
      expect(subject.recipients).to be_empty
    end
  end
end
