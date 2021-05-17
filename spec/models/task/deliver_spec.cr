require "../../../src/models/task/deliver"

require "../../spec_helper/model"
require "../../spec_helper/network"
require "../../spec_helper/register"

Spectator.describe Task::Deliver do
  setup_spec

  let(sender) do
    register(with_keys: true).actor
  end
  let(activity) do
    ActivityPub::Activity.new(iri: "https://test.test/activities/activity")
  end

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

  let(local_recipient) do
    username = random_string
    ActivityPub::Actor.new(
      iri: "https://test.test/actors/#{username}",
      inbox: "https://test.test/actors/#{username}/inbox"
    )
  end

  let(remote_recipient) do
    username = random_string
    ActivityPub::Actor.new(
      iri: "https://remote/actors/#{username}",
      inbox: "https://remote/actors/#{username}/inbox"
    )
  end

  let(local_collection) do
    ActivityPub::Collection.new(
      iri: "https://test.test/actors/#{random_string}/followers"
    )
  end

  let(remote_collection) do
    ActivityPub::Collection.new(
      iri: "https://remote/actors/#{random_string}/followers"
    )
  end

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
          Relationship::Social::Follow.new(
            actor: local_recipient,
            object: sender,
            confirmed: true
          ).save
          Relationship::Social::Follow.new(
            actor: remote_recipient,
            object: sender,
            confirmed: true
          ).save
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

  describe "#deliver" do
    subject do
      described_class.new(
        sender: sender,
        activity: activity
      )
    end

    before_each do
      local_recipient.save
      remote_recipient.save
    end

    alias Timeline = Relationship::Content::Timeline

    context "when activity is a create" do
      let!(object) do
        ActivityPub::Object.new(
          iri: "https://test.test/objects/object",
          attributed_to: sender
        ).save
      end
      let(activity) do
        ActivityPub::Activity::Create.new(
          iri: "https://test.test/activities/create",
          object: object
        )
      end

      it "puts the object in the sender's timeline" do
        expect{subject.deliver([sender.iri])}.
          to change{Timeline.count(from_iri: sender.iri)}.by(1)
      end

      context "and the object's already in the timeline" do
        before_each do
          Timeline.new(
            owner: sender,
            object: object
          ).save
        end

        it "does not put the object in the sender's timeline" do
          expect{subject.deliver([sender.iri])}.
            not_to change{Timeline.count(from_iri: sender.iri)}
        end
      end

      context "and the object is a reply" do
        before_each do
          object.assign(
            in_reply_to: ActivityPub::Object.new(
              iri: "https://remote/objects/reply"
            )
          ).save
        end

        it "does not put the object in the sender's timeline" do
          expect{subject.deliver([sender.iri])}.
            not_to change{Timeline.count(from_iri: sender.iri)}
        end
      end
    end

    context "when activity is an announce" do
      let!(object) do
        ActivityPub::Object.new(
          iri: "https://test.test/objects/object",
          attributed_to: sender
        ).save
      end
      let(activity) do
        ActivityPub::Activity::Announce.new(
          iri: "https://remote/activities/announce",
          object: object
        )
      end

      it "puts the object in the sender's timeline" do
        expect{subject.deliver([sender.iri])}.
          to change{Timeline.count(from_iri: sender.iri)}.by(1)
      end

      context "and the object's already in the timeline" do
        before_each do
          Timeline.new(
            owner: sender,
            object: object
          ).save
        end

        it "does not put the object in the sender's timeline" do
          expect{subject.deliver([sender.iri])}.
            not_to change{Timeline.count(from_iri: sender.iri)}
        end
      end

      context "and the object is a reply" do
        before_each do
          object.assign(
            in_reply_to: ActivityPub::Object.new(
              iri: "https://remote/objects/reply"
            )
          ).save
        end

        it "puts the object in the sender's timeline" do
          expect{subject.deliver([sender.iri])}.
            to change{Timeline.count(from_iri: sender.iri)}.by(1)
        end
      end
    end

    it "puts the activity in the outbox of the sender" do
      expect{subject.deliver([sender.iri])}.
        to change{Relationship::Content::Outbox.count(from_iri: sender.iri)}.by(1)
    end

    it "does not put the object in the sender's timeline" do
      expect{subject.deliver([sender.iri])}.
        not_to change{Timeline.count(from_iri: sender.iri)}
    end

    it "puts the activity in the inbox of a local recipient" do
      subject.deliver([local_recipient.iri])
      expect(Relationship::Content::Inbox.count(from_iri: local_recipient.iri)).to eq(1)
    end

    it "sends the activity to the inbox of a remote recipient" do
      subject.deliver([remote_recipient.iri])
      expect(HTTP::Client.requests).to have("POST #{remote_recipient.inbox}")
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
      let(activity) do
        ActivityPub::Activity::Delete.new(
          iri: "https://test.test/activities/delete",
          actor_iri: sender.iri,
          object_iri: "https://deleted",
          to: [local_recipient.iri, remote_recipient.iri]
        )
      end

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
