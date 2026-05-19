require "../../../src/models/task/terminate"

require "../../spec_helper/base"
require "../../spec_helper/factory"

Spectator.describe Task::Terminate do
  setup_spec

  let(actor) { register.actor }

  let(options) do
    {
      source_iri:  actor.iri,
      subject_iri: actor.iri,
    }
  end

  context "validation" do
    it "rejects missing source" do
      new_relationship = described_class.new(**options.merge({source_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain_exactly("source")
    end

    it "rejects missing subject" do
      new_relationship = described_class.new(**options.merge({subject_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.values.flatten).to contain_exactly("missing: missing")
    end

    it "rejects remote subject" do
      actor.assign(iri: "https://remote/actors/actor").save
      new_relationship = described_class.new(**options.merge({subject_iri: actor.iri}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.values.flatten).to contain_exactly("remote: #{actor.iri}")
    end

    it "successfully validates instance" do
      new_relationship = described_class.new(**options)
      expect(new_relationship.valid?).to be_true
    end
  end

  describe "#perform" do
    subject do
      described_class.new(
        source: actor,
        subject: actor,
      )
    end

    context "when an object exists" do
      let_create!(:object, attributed_to: actor)

      it "deletes the object" do
        expect { subject.perform }
          .to change { ActivityPub::Object.count(attributed_to_iri: actor.iri) }.by(-1)
      end

      context "when the object is published" do
        before_each { object.assign(published: Time.utc).save }

        it "creates a delete activity for the object" do
          expect { subject.perform }
            .to change { ActivityPub::Activity::Delete.count(object_iri: object.iri) }.by(1)
        end

        it "schedules a task to deliver the activity" do
          expect { subject.perform }
            .to change { Task::Deliver.count }.by(1)
        end
      end

      it "reschedules itself" do
        expect { subject.perform }
          .to change { subject.next_attempt_at }
      end
    end

    context "when no objects exist" do
      it "deletes the actor" do
        expect { subject.perform }
          .to change { ActivityPub::Actor.count(iri: actor.iri) }.by(-1)
      end

      it "destroys the account" do
        expect { subject.perform }
          .to change { Account.count(iri: actor.iri) }.by(-1)
      end

      it "creates a delete activity for the actor" do
        expect { subject.perform }
          .to change { ActivityPub::Activity::Delete.count(object_iri: actor.iri) }.by(1)
      end

      context "and there are remote followers" do
        let_create(:actor, named: :remote_follower)
        before_each { do_follow(remote_follower, actor) }

        it "schedules a task to deliver the activity" do
          expect { subject.perform }
            .to change { Task::Deliver.count }.by(1)
        end
      end

      it "does not reschedule itself" do
        expect { subject.perform }
          .not_to change { subject.next_attempt_at }
      end

      context "and the actor is already deleted" do
        # production crash-recovery path

        before_each { actor.delete! }

        let(terminate) { Task::Terminate.find(subject.save.id) }

        it "destroys the account" do
          expect { terminate.perform }
            .to change { Account.count(iri: actor.iri) }.by(-1)
        end

        it "does not create a delete activity" do
          expect { terminate.perform }
            .not_to change { ActivityPub::Activity::Delete.count(object_iri: actor.iri) }
        end

        it "does not reschedule itself" do
          expect { terminate.perform }
            .not_to change { terminate.next_attempt_at }
        end
      end
    end
  end
end
