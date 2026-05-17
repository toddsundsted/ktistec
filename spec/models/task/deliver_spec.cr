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

  let_build(:actor, named: :local_recipient, username: "local", local: true)
  let_build(:actor, named: :remote_recipient, username: "remote")

  describe "#perform" do
    subject do
      described_class.new(
        sender: sender,
        activity: activity,
      )
    end

    context "when the object has been deleted" do
      let_build(:delete, named: :activity, actor_iri: sender.iri, object_iri: "https://deleted", to: [local_recipient.iri, remote_recipient.iri])

      before_each do
        local_recipient.save
        remote_recipient.save
      end

      it "does not fail" do
        expect { subject.perform }.not_to change { subject.failures }
      end
    end
  end
end
