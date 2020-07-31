require "../../spec_helper"

Spectator.describe Task::Send do
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
      expect(new_relationship.errors.keys).to contain("actor")
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

    let(activity) do
      ActivityPub::Activity.new(
        iri: "https://test.test/activities/#{random_string}"
      )
    end

    subject do
      described_class.new(
        actor: actor,
        activity: activity
      )
    end

    context "given a remote recipient" do
      let!(recipient) do
        username = random_string
        ActivityPub::Actor.new(
          iri: "https://remote/actors/#{username}",
          inbox: "https://remote/actors/#{username}/inbox",
        ).tap do |actor|
          activity.to = [actor.iri]
        end
      end

      context "when cached" do
        before_each { recipient.save }

        it "sends the activity to the recipient's inbox" do
          subject.perform
          expect(HTTP::Client.requests).to have("POST #{recipient.inbox}")
        end
      end

      context "when not cached" do
        before_each { HTTP::Client.actors << recipient }

        it "retrieves the recipient" do
          subject.perform
          expect(HTTP::Client.requests).to have("GET #{recipient.iri}")
        end

        it "sends the activity to the recipient's inbox" do
          subject.perform
          expect(HTTP::Client.requests).to have("POST #{recipient.inbox}")
        end
      end
    end

    context "given a local recipient" do
      let!(recipient) do
        username = random_string
        ActivityPub::Actor.new(
          iri: "https://test.test/actors/#{username}",
          inbox: "https://test.test/actors/#{username}/inbox",
        ).save.tap do |actor|
          activity.to = [actor.iri]
        end
      end

      it "puts the activity in the recipient's inbox" do
        expect{subject.perform}.to change{Relationship::Content::Inbox.count}.by(1)
      end
    end
  end
end
