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

    context "addressed to the sender" do
      let(recipient) { sender }

      before_each { activity.to = [recipient.iri] }

      it "excludes the sender" do
        expect(subject.recipients).not_to contain(recipient.iri)
      end
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

    it "puts the activity in the inbox of a local recipient" do
      subject.deliver([local_recipient.iri])
      expect(Relationship::Content::Inbox.count(from_iri: local_recipient.iri)).to eq(1)
    end

    it "sends the activity to the inbox of a remote recipient" do
      subject.deliver([remote_recipient.iri])
      expect(HTTP::Client.requests).to have("POST #{remote_recipient.inbox}")
    end
  end
end
