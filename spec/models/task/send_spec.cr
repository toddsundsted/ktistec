require "../../spec_helper"

Spectator.describe Task::Send do
  before_each { HTTP::Client.reset }
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  context "validation" do
    let(options) do
      {
        source_iri: ActivityPub::Actor.new(iri: "https://test.test/#{random_string}").save.iri,
        subject_iri: ActivityPub::Activity.new(iri: "https://test.test/#{random_string}").save.iri
      }
    end

    it "rejects missing actor" do
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

  describe "#perform" do
    let(actor) { register(with_keys: true).actor }

    let(remote_recipient) do
      username = random_string
      ActivityPub::Actor.new(
        iri: "https://remote/actors/#{username}",
        inbox: "https://remote/actors/#{username}/inbox",
      )
    end

    let(local_recipient) do
      username = random_string
      ActivityPub::Actor.new(
        iri: "https://test.test/actors/#{username}",
        inbox: "https://test.test/actors/#{username}/inbox",
      )
    end

    let(remote_collection) do
      ActivityPub::Collection.new(
        iri: "https://remote/actors/#{random_string}/followers"
      )
    end

    let(local_collection) do
      Relationship::Social::Follow.new(
        actor: actor,
        object: local_recipient
      ).save
      Relationship::Social::Follow.new(
        actor: actor,
        object: remote_recipient
      ).save
      ActivityPub::Collection.new(
        iri: "#{actor.iri}/followers"
      )
    end

    let(reply) do
      ActivityPub::Object.new(
        iri: "https://remote/objects/#{random_string}",
        in_reply_to: "https://test.test/objects/#{random_string}"
      )
    end

    subject do
      described_class.new(
        sender: actor,
        activity: activity
      )
    end

    context "given an activity of remote origin" do
      let(activity) do
        ActivityPub::Activity.new(
          iri: "https://remote/activities/#{random_string}",
          actor_iri: "https://remote/actors/#{random_string}"
        )
      end

      context "addressed to a remote recipient" do
        let(recipient) { remote_recipient }
        before_each { activity.to = [recipient.iri]}

        it "does not send the activity to the recipient's inbox" do
          subject.perform
          expect(HTTP::Client.requests).not_to have("POST #{recipient.inbox}")
        end
      end

      context "addressed to a local recipient" do
        let(recipient) { local_recipient.save }
        before_each { activity.to = [recipient.iri]}

        it "puts the activity in the recipient's inbox" do
          expect{subject.perform}.
            to change{Relationship::Content::Inbox.count(from_iri: local_recipient.iri)}.by(1)
        end
      end

      context "addressed to a remote collection" do
        let(recipient) { remote_collection }
        before_each { activity.to = [recipient.iri]}

        it "ignores the remote collection" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end

      context "addressed to a local collection" do
        let(recipient) { local_collection }
        before_each { activity.to = [recipient.iri]}

        context "and a remote reply to a local object" do
          before_each { activity.object_iri = reply.iri }

          context "when cached" do
            before_each { reply.save }

            it "puts the activity in the local recipient's inbox" do
              expect{subject.perform}.
                to change{Relationship::Content::Inbox.count(from_iri: local_recipient.iri)}.by(1)
            end

            it "sends the activity to the remote recipient's inbox" do
              subject.perform
              expect(HTTP::Client.requests).to have("POST #{remote_recipient.inbox}")
            end
          end

          context "when not cached" do
            before_each { HTTP::Client.objects << reply }

            it "puts the activity in the local recipient's inbox" do
              expect{subject.perform}.
                to change{Relationship::Content::Inbox.count(from_iri: local_recipient.iri)}.by(1)
            end

            it "sends the activity to the remote recipient's inbox" do
              subject.perform
              expect(HTTP::Client.requests).to have("POST #{remote_recipient.inbox}")
            end
          end
        end

        it "does not put the activity in the local recipient's inbox" do
          expect{subject.perform}.
            not_to change{Relationship::Content::Inbox.count}
        end

        it "does not send the activity to the remote recipient's inbox" do
          subject.perform
          expect(HTTP::Client.requests).not_to have("POST #{remote_recipient.inbox}")
        end
      end
    end

    context "given an activity of local origin" do
      let(activity) do
        ActivityPub::Activity.new(
          iri: "https://test.test/activities/#{random_string}",
          actor_iri: actor.iri
        )
      end

      context "addressed to a remote recipient" do
        let(recipient) { remote_recipient }
        before_each { activity.to = [recipient.iri]}

        context "when cached" do
          before_each { recipient.save }

          it "sends the activity to the recipient's inbox" do
            subject.perform
            expect(HTTP::Client.requests).to have("POST #{recipient.inbox}")
          end
        end

        context "when not cached" do
          before_each { HTTP::Client.actors << recipient }

          it "sends the activity to the recipient's inbox" do
            subject.perform
            expect(HTTP::Client.requests).to have("POST #{recipient.inbox}")
          end
        end
      end

      context "addressed to a local recipient" do
        let(recipient) { local_recipient.save }
        before_each { activity.to = [recipient.iri]}

        it "puts the activity in the recipient's inbox" do
          expect{subject.perform}.
            to change{Relationship::Content::Inbox.count(from_iri: local_recipient.iri)}.by(1)
        end
      end

      context "addressed to a remote collection" do
        let(recipient) { remote_collection }
        before_each { activity.to = [recipient.iri]}

        it "ignores the remote collection" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end

      context "addressed to a local collection" do
        let(recipient) { local_collection }
        before_each { activity.to = [recipient.iri]}

        it "puts the activity in the local recipient's inbox" do
          expect{subject.perform}.
            to change{Relationship::Content::Inbox.count(from_iri: local_recipient.iri)}.by(1)
        end

        it "sends the activity to the remote recipient's inbox" do
          subject.perform
          expect(HTTP::Client.requests).to have("POST #{remote_recipient.inbox}")
        end
      end
    end
  end
end
