require "../../../src/models/task/deliver_delayed_object"
require "../../../src/services/outbox_activity_processor"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::DeliverDelayedObject do
  setup_spec

  let(actor) { register.actor }
  let_create(:object, published: nil, visible: true, local: true, attributed_to: actor)

  alias State = Task::DeliverDelayedObject::State

  let(state) { State.new(State::Reason::Scheduled, State::ScheduledContext.new(1.hour.ago)) }

  context "validation" do
    let!(options) do
      {source_iri: actor.iri, subject_iri: object.iri, state: state}
    end

    it "rejects missing actor" do
      new_task = described_class.new(**options.merge({source_iri: "https://missing/actor"}))
      expect(new_task.valid?).to be_false
      expect(new_task.errors.keys).to contain("actor")
    end

    it "rejects missing object" do
      new_task = described_class.new(**options.merge({subject_iri: "https://missing/object"}))
      expect(new_task.valid?).to be_false
      expect(new_task.errors.keys).to contain("object")
    end

    it "successfully validates instance" do
      new_task = described_class.new(**options)
      expect(new_task.valid?).to be_true
    end
  end

  describe "#reason" do
    subject { described_class.new(actor: actor, object: object, state: state) }

    it "retrieves the reason from state" do
      expect(subject.reason).to eq(State::Reason::Scheduled)
    end
  end

  describe "#perform" do
    subject { described_class.new(actor: actor, object: object, state: state) }

    it "creates an activity" do
      expect { subject.perform }.to change { ActivityPub::Activity::Create.count }.by(1)
    end

    it "adds activity to the outbox" do
      expect { subject.perform }.to change { actor.in_outbox?(object, ActivityPub::Activity::Create) }.from(false).to(true)
    end

    it "sets published" do
      expect { subject.perform }.to change { object.reload!.published }.from(nil)
      activity = ActivityPub::Activity::Create.find(actor: actor, object: object)
      expect(activity.published).not_to be_nil
    end

    it "schedules delivery" do
      expect { subject.perform }.to change { Task::Deliver.count }.by(1)
    end

    context "when object is not local" do
      before_each { object.assign(iri: "https://remote/object").save }

      it "does not create an activity" do
        expect { subject.perform }.not_to change { ActivityPub::Activity::Create.count }
      end
    end

    context "when object is already published" do
      before_each { object.assign(published: Time.utc).save }

      it "does not create an activity" do
        expect { subject.perform }.not_to change { ActivityPub::Activity::Create.count }
      end
    end

    context "when object is deleted" do
      before_each { object.delete! }

      it "does not create an activity" do
        expect { subject.perform }.not_to change { ActivityPub::Activity::Create.count }
      end
    end

    context "when object does not exist" do
      subject { described_class.new(actor: actor, subject_iri: "https://missing/object", state: state) }

      it "does not create an activity" do
        expect { subject.perform }.not_to change { ActivityPub::Activity::Create.count }
      end
    end

    context "when actor is deleted" do
      before_each { actor.delete! }

      it "does not create an activity" do
        expect { subject.perform }.not_to change { ActivityPub::Activity::Create.count }
      end
    end

    context "when object has no actor" do
      before_each { object.assign(attributed_to_iri: nil).save }

      subject { described_class.new(actor: actor, subject_iri: object.iri, state: state) }

      it "does not create an activity" do
        expect { subject.perform }.not_to change { ActivityPub::Activity::Create.count }
      end
    end

    context "when no account exists for the actor" do
      before_each { Account.find(iri: actor.iri).destroy }

      it "does not create an activity" do
        expect { subject.perform }.not_to change { ActivityPub::Activity::Create.count }
      end
    end

    context "when object is already in the actor's outbox" do
      let_create!(:create, actor: actor, object: object)

      before_each { put_in_outbox(actor, create) }

      it "does not create an activity" do
        expect { subject.perform }.not_to change { ActivityPub::Activity::Create.count }
      end
    end
  end
end
