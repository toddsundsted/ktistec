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
    let!(actor) { register(with_keys: true).actor }

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

    let(remote_actor) do
      username = random_string
      ActivityPub::Actor.new(
        iri: "https://remote/actors/#{username}",
        followers: "https://remote/actors/#{username}/followers"
      )
    end

    let(remote_collection) do
      ActivityPub::Collection.new(
        iri: "#{remote_actor.iri}/followers"
      )
    end

    let(local_collection) do
      Relationship::Social::Follow.new(
        actor: local_recipient,
        object: actor
      ).save
      Relationship::Social::Follow.new(
        actor: remote_recipient,
        object: actor
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
          actor_iri: remote_actor.iri
        )
      end

      context "addressed to a remote recipient" do
        let(recipient) { remote_recipient }
        before_each do
          HTTP::Client.actors << recipient
          activity.to = [recipient.iri]
        end

        it "does not put it in an inbox" do
          expect{subject.perform}.
            not_to change{Relationship::Content::Inbox.count}
        end

        it "does not forward it" do
          subject.perform
          expect(HTTP::Client.requests).not_to have(/POST/)
        end

        it "does not fail" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end

      context "addressed to a local recipient" do
        let(recipient) { local_recipient }
        before_each do
          recipient.save
          activity.to = [recipient.iri]
        end

        it "does not put it in an inbox" do
          expect{subject.perform}.
            not_to change{Relationship::Content::Inbox.count}
        end

        it "does not forward it" do
          subject.perform
          expect(HTTP::Client.requests).not_to have(/POST/)
        end

        it "does not fail" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end

      context "addressed to the actor" do
        let(recipient) { actor }
        before_each do
          recipient.save
          activity.to = [recipient.iri]
        end

        it "puts it in the actors's inbox" do
          expect{subject.perform}.
            to change{Relationship::Content::Inbox.count(from_iri: actor.iri, to_iri: activity.iri)}.by(1)
        end

        it "does not forward it" do
          subject.perform
          expect(HTTP::Client.requests).not_to have(/POST/)
        end

        it "does not fail" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end

      context "addressed to a remote collection" do
        let(recipient) { remote_collection }
        before_each do
          HTTP::Client.collections << recipient
          activity.to = [recipient.iri]
        end

        context "in which the actor is a follower" do
          before_each do
            Relationship::Social::Follow.new(
              actor: actor,
              object: remote_actor
            ).save
          end

          it "puts it in the actors's inbox" do
            expect{subject.perform}.
              to change{Relationship::Content::Inbox.count(from_iri: actor.iri, to_iri: activity.iri)}.by(1)
          end
        end

        it "does not put it in an inbox" do
          expect{subject.perform}.
            not_to change{Relationship::Content::Inbox.count}
        end

        it "does not forward it" do
          subject.perform
          expect(HTTP::Client.requests).not_to have(/POST/)
        end

        it "does not fail" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end

      context "addressed to a local collection" do
        let(recipient) { local_collection }
        before_each do
          recipient.save
          activity.to = [recipient.iri]
        end

        context "in reply to a local object" do
          before_each { activity.object_iri = reply.iri }

          context "when cached" do
            before_each { reply.save }

            it "puts the activity in the local recipient's inbox" do
              expect{subject.perform}.
                to change{Relationship::Content::Inbox.count(from_iri: local_recipient.iri, to_iri: activity.iri)}.by(1)
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
                to change{Relationship::Content::Inbox.count(from_iri: local_recipient.iri, to_iri: activity.iri)}.by(1)
            end

            it "sends the activity to the remote recipient's inbox" do
              subject.perform
              expect(HTTP::Client.requests).to have("POST #{remote_recipient.inbox}")
            end
          end

          context "when object doesn't exist" do
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

        it "does not put it in an inbox" do
          expect{subject.perform}.
            not_to change{Relationship::Content::Inbox.count}
        end

        it "does not forward it" do
          subject.perform
          expect(HTTP::Client.requests).not_to have(/POST/)
        end

        it "does not fail" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end

      context "addressed to the public collection" do
        before_each { activity.to = ["https://www.w3.org/ns/activitystreams#Public"] }

        context "and the actor is a follower" do
          before_each do
            Relationship::Social::Follow.new(
              actor: actor,
              object: remote_actor
            ).save
          end

          it "puts it in the actors's inbox" do
            expect{subject.perform}.
              to change{Relationship::Content::Inbox.count(from_iri: actor.iri, to_iri: activity.iri)}.by(1)
          end
        end

        it "does not put it in an inbox" do
          expect{subject.perform}.
            not_to change{Relationship::Content::Inbox.count}
        end

        it "does not forward it" do
          subject.perform
          expect(HTTP::Client.requests).not_to have(/POST/)
        end

        it "does not fail" do
          subject.perform
          expect(subject.failures).to be_empty
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
        before_each do
          activity.to = [recipient.iri]
        end

        context "when cached" do
          before_each { recipient.save }

          it "does not put it in an inbox" do
            expect{subject.perform}.
              not_to change{Relationship::Content::Inbox.count}
          end

          it "sends the activity to the recipient's inbox" do
            subject.perform
            expect(HTTP::Client.requests).to have("POST #{recipient.inbox}")
          end

          it "does not fail" do
            subject.perform
            expect(subject.failures).to be_empty
          end
        end

        context "when not cached" do
          before_each { HTTP::Client.actors << recipient }

          it "does not put it in an inbox" do
            expect{subject.perform}.
              not_to change{Relationship::Content::Inbox.count}
          end

          it "sends the activity to the recipient's inbox" do
            subject.perform
            expect(HTTP::Client.requests).to have("POST #{recipient.inbox}")
          end

          it "does not fail" do
            subject.perform
            expect(subject.failures).to be_empty
          end
        end
      end

      context "addressed to a local recipient" do
        let(recipient) { local_recipient }
        before_each do
          recipient.save
          activity.to = [recipient.iri]
        end

        it "puts the activity in the recipient's inbox" do
          expect{subject.perform}.
            to change{Relationship::Content::Inbox.count(from_iri: local_recipient.iri, to_iri: activity.iri)}.by(1)
        end

        it "does not send it" do
          subject.perform
          expect(HTTP::Client.requests).not_to have(/POST/)
        end

        it "does not fail" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end

      context "addressed to the actor" do
        let(recipient) { actor }
        before_each do
          recipient.save
          activity.to = [recipient.iri]
        end

        it "does not put it in an inbox" do
          expect{subject.perform}.
            not_to change{Relationship::Content::Inbox.count}
        end

        it "does not send it" do
          subject.perform
          expect(HTTP::Client.requests).not_to have(/POST/)
        end

        it "does not fail" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end

      context "addressed to a remote collection" do
        let(recipient) { remote_collection }
        before_each do
          HTTP::Client.collections << recipient
          activity.to = [recipient.iri]
        end

        it "does not put it in an inbox" do
          expect{subject.perform}.
            not_to change{Relationship::Content::Inbox.count}
        end

        it "does not send it" do
          subject.perform
          expect(HTTP::Client.requests).not_to have(/POST/)
        end

        it "does not fail" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end

      context "addressed to a local collection" do
        let(recipient) { local_collection }
        before_each do
          recipient.save
          activity.to = [recipient.iri]
        end

        it "puts the activity in the local recipient's inbox" do
          expect{subject.perform}.
            to change{Relationship::Content::Inbox.count(from_iri: local_recipient.iri, to_iri: activity.iri)}.by(1)
        end

        it "sends the activity to the remote recipient's inbox" do
          subject.perform
          expect(HTTP::Client.requests).to have("POST #{remote_recipient.inbox}")
        end

        it "does not fail" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end

      context "addressed to the public collection" do
        before_each { activity.to = ["https://www.w3.org/ns/activitystreams#Public"] }

        context "and the actor has followers" do
          before_each { local_collection }

          it "puts the activity in the local follower's inbox" do
            expect{subject.perform}.
              to change{Relationship::Content::Inbox.count(from_iri: local_recipient.iri, to_iri: activity.iri)}.by(1)
          end

          it "sends the activity to the remote follower's inbox" do
            subject.perform
            expect(HTTP::Client.requests).to have("POST #{remote_recipient.inbox}")
          end
        end

        it "does not put it in an inbox" do
          expect{subject.perform}.
            not_to change{Relationship::Content::Inbox.count}
        end

        it "does not send it" do
          subject.perform
          expect(HTTP::Client.requests).not_to have(/POST/)
        end

        it "does not fail" do
          subject.perform
          expect(subject.failures).to be_empty
        end
      end
    end
  end
end
