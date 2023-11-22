require "../../../src/models/task/receive"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/network"

Spectator.describe Task::Receive do
  setup_spec

  let(receiver) do
    register.actor
  end

  let_build(:activity)

  context "validation" do
    let!(options) do
      {source_iri: receiver.save.iri, subject_iri: activity.save.iri}
    end

    it "rejects missing receiver" do
      new_relationship = described_class.new(**options.merge({source_iri: "missing"}))
      expect(new_relationship.valid?).to be_false
      expect(new_relationship.errors.keys).to contain("receiver")
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

  describe "#deliver_to" do
    subject do
      described_class.new(
        receiver: receiver,
        activity: activity
      )
    end

    it "retrieves the deliver to value from the state" do
      subject.state = Task::Receive::State.new([] of String)
      expect(subject.deliver_to).to be_a(Array(String))
    end

    it "retrieves the deliver to value from the state" do
      subject.state = Task::Receive::State.new([] of String)
      expect(subject.deliver_to).to be_empty
    end
  end

  describe "#deliver_to=" do
    subject do
      described_class.new(
        receiver: receiver,
        activity: activity
      )
    end

    it "stores the deliver to value in the state" do
      subject.deliver_to = ["https://recipient"]
      expect(subject.state.deliver_to).to eq(["https://recipient"])
    end
  end

  let_build(:actor, named: :local_recipient, iri: "https://test.test/actors/local")
  let_build(:actor, named: :remote_recipient, iri: "https://remote/actors/remote")

  let_build(:collection, named: :local_collection, iri: "https://test.test/collections/local")
  let_build(:collection, named: :remote_collection, iri: "https://remote/collections/remote")

  describe "#recipients" do
    subject do
      described_class.new(
        receiver: receiver,
        activity: activity
      )
    end

    it "does not include the receiver by default" do
      expect(subject.recipients).not_to contain(receiver.iri)
    end

    context "addressed to the receiver" do
      let(recipient) { receiver }

      before_each { activity.to = [recipient.iri] }

      it "includes the receiver" do
        expect(subject.recipients).to contain(recipient.iri)
      end
    end

    context "addressed to a local recipient" do
      let(recipient) { local_recipient }

      before_each { activity.to = [recipient.iri] }

      it "does not include the recipient" do
        expect(subject.recipients).not_to contain(recipient.iri)
      end
    end

    context "addressed to a remote recipient" do
      let(recipient) { remote_recipient }

      before_each { activity.to = [recipient.iri] }

      it "does not include the recipient" do
        expect(subject.recipients).not_to contain(recipient.iri)
      end
    end

    context "addressed to a local collection" do
      let(recipient) { local_collection }

      before_each { activity.to = [recipient.iri] }

      it "does not include the collection" do
        expect(subject.recipients).not_to contain(recipient.iri)
      end

      context "of the receiver's followers" do
        let(recipient) { local_collection.assign(iri: "#{receiver.iri}/followers") }

        before_each do
          do_follow(local_recipient, receiver)
          do_follow(remote_recipient, receiver)
        end

        context "given a reply" do
          let_build(:object, named: :original, attributed_to: receiver)
          let_build(:object, named: :reply, in_reply_to: original)

          before_each do
            activity.object_iri = reply.iri
            original.save
            reply.save
          end

          it "does not include the collection" do
            expect(subject.recipients).not_to contain(recipient.iri)
          end

          it "does not include the followers" do
            expect(subject.recipients).not_to contain(local_recipient.iri, remote_recipient.iri)
          end

          context "which is addressed to the local collection" do
            before_each do
              original.to = [recipient.iri]
              reply.to = [recipient.iri]
              original.save
              reply.save
            end

            it "includes the followers" do
              expect(subject.recipients).to contain(local_recipient.iri, remote_recipient.iri)
            end

            context "when follows are not confirmed" do
              before_each do
                Relationship::Social::Follow.where(to_iri: receiver.iri).each do |follow|
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

            context "when the original is not attributed to the receiver" do
              before_each do
                original.assign(attributed_to: remote_recipient).save
              end

              it "does not include the followers" do
                expect(subject.recipients).not_to contain(local_recipient.iri, remote_recipient.iri)
              end

              context "but it is itself a reply to another post by the receiver" do
                let_build(:object, named: :another, attributed_to: receiver, to: [recipient.iri])

                before_each do
                  original.assign(in_reply_to: another).save
                end

                it "includes the followers" do
                  expect(subject.recipients).to contain(local_recipient.iri, remote_recipient.iri)
                end

                context "unless it doesn't address the local colletion" do
                  before_each do
                    original.to = [remote_collection.iri]
                    original.save
                  end

                  it "does not include the followers" do
                    expect(subject.recipients).not_to contain(local_recipient.iri, remote_recipient.iri)
                  end
                end
              end
            end
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

      it "does not include the receiver" do
        expect(subject.recipients).not_to contain(receiver.iri)
      end

      context "of the senders's followers" do
        let_build(:actor, named: :sender)

        let(recipient) { remote_collection.assign(iri: "#{sender.iri}/followers") }

        before_each do
          activity.actor_iri = sender.iri
          HTTP::Client.collections << recipient
          do_follow(receiver, sender)
        end

        it "includes the receiver" do
          expect(subject.recipients).to contain(receiver.iri)
        end

        context "when collection isn't the followers collection" do
          let(recipient) { remote_collection.assign(iri: "#{sender.iri}/collection") }

          it "does not include the receiver" do
            expect(subject.recipients).not_to contain(receiver.iri)
          end
        end

        context "when follows are not confirmed" do
          before_each do
            Relationship::Social::Follow.where(from_iri: receiver.iri).each do |follow|
              follow.assign(confirmed: false).save
            end
          end

          it "does not include the receiver" do
            expect(subject.recipients).not_to contain(receiver.iri)
          end
        end
      end
    end

    context "addressed to the public collection" do
      PUBLIC = "https://www.w3.org/ns/activitystreams#Public"

      before_each { activity.to = [PUBLIC] }

      it "does not include the collection" do
        expect(subject.recipients).not_to contain(PUBLIC)
      end

      it "does not include the receiver" do
        expect(subject.recipients).not_to contain(receiver.iri)
      end

      context "the receiver is a follower of the sender" do
        let_build(:actor, named: :sender)

        before_each do
          activity.actor_iri = sender.iri
          do_follow(receiver, sender)
        end

        it "includes the receiver" do
          expect(subject.recipients).to contain(receiver.iri)
        end
      end
    end
  end

  describe "#perform" do
    subject do
      described_class.new(
        receiver: receiver,
        activity: activity
      )
    end

    context "when the object has already been deleted" do
      let_build(:delete, named: :activity, actor_iri: receiver.iri, object_iri: "https://deleted", to: [receiver.iri])

      it "does not fail" do
        expect{subject.perform}.not_to change{subject.failures}
      end
    end
  end
end
