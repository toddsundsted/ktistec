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

  let_build(:actor, named: :local_recipient, iri: "https://test.test/actors/local")
  let_build(:actor, named: :remote_recipient, iri: "https://remote/actors/remote")

  let_build(:collection, named: :local_collection, iri: "https://test.test/collections/local")
  let_build(:collection, named: :remote_collection, iri: "https://remote/collections/remote")

  describe "#recipients" do
    subject do
      described_class.new(
        sender: sender,
        activity: activity
      )
    end

    it "includes the sender by default" do
      expect(subject.recipients).to contain(sender.iri)
    end

    context "addressed to a local recipient" do
      let(recipient) { local_recipient.save }

      before_each { activity.to = [recipient.iri] }

      it "includes the recipient" do
        expect(subject.recipients).to contain(recipient.iri)
      end
    end

    context "addressed to a remote recipient" do
      let(recipient) { remote_recipient }

      before_each { activity.to = [recipient.iri] }

      context "that is cached" do
        before_each { recipient.save }

        it "includes the recipient" do
          expect(subject.recipients).to contain(recipient.iri)
        end
      end

      context "that is not cached" do
        before_each { HTTP::Client.actors << recipient }

        it "includes the recipient" do
          expect(subject.recipients).to contain(recipient.iri)
        end
      end
    end

    context "addressed to a local collection" do
      let(recipient) { local_collection }

      before_each { activity.to = [recipient.iri] }

      it "does not include the collection" do
        expect(subject.recipients).not_to contain(recipient.iri)
      end

      context "of the sender's followers" do
        let(recipient) { local_collection.assign(iri: "#{sender.iri}/followers") }

        before_each do
          do_follow(local_recipient, sender)
          do_follow(remote_recipient, sender)
        end

        it "does not include the collection" do
          expect(subject.recipients).not_to contain(recipient.iri)
        end

        it "includes the followers" do
          expect(subject.recipients).to contain(local_recipient.iri, remote_recipient.iri)
        end

        context "when follows are not confirmed" do
          before_each do
            Relationship::Social::Follow.where(to_iri: sender.iri).each do |follow|
              follow.assign(confirmed: false).save
            end
          end

          it "does not include the followers" do
            expect(subject.recipients).not_to contain(local_recipient.iri, remote_recipient.iri)
          end
        end

        context "when followers have been deleted" do
          before_each do
            local_recipient.delete
            remote_recipient.delete
          end

          it "does not include the recipients" do
            expect(subject.recipients).not_to contain(local_recipient.iri, remote_recipient.iri)
          end
        end
      end
    end

    context "addressed to a remote collection" do
      let(recipient) { remote_collection }

      before_each { activity.to = [recipient.iri] }

      it "does not include the collection" do
        expect(subject.recipients).not_to contain(recipient.iri)
      end
    end

    context "addressed to the public collection" do
      PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

      before_each { activity.to = [PUBLIC] }

      it "does not include the collection" do
        expect(subject.recipients).not_to contain(PUBLIC)
      end
    end
  end

  describe "#perform" do
    subject do
      described_class.new(
        sender: sender,
        activity: activity
      )
    end

    context "when the object has been deleted" do
      let_build(:delete, named: :activity, actor_iri: sender.iri, object_iri: "https://deleted", to: [local_recipient.iri, remote_recipient.iri])

      before_each do
        local_recipient.save
        remote_recipient.save
      end

      it "does not fail" do
        expect{subject.perform}.not_to change{subject.failures}
      end
    end
  end
end
