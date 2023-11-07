require "../../../../src/models/activity_pub/activity/follow"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Activity::Follow do
  setup_spec

  subject { described_class.new(iri: "http://test.test/#{random_string}").save }

  describe "#actor" do
    it "returns an actor or actor subclass" do
      expect(typeof(subject.actor)).to eq({{(ActivityPub::Actor.all_subclasses << ActivityPub::Actor).join("|").id}})
    end
  end

  describe "#object" do
    it "returns an actor or actor subclass" do
      expect(typeof(subject.object)).to eq({{(ActivityPub::Actor.all_subclasses << ActivityPub::Actor).join("|").id}})
    end
  end

  describe "#accepted_or_rejected" do
    it "returns nil" do
      expect(subject.accepted_or_rejected?).to be_nil
    end

    context "when accepted" do
      let_create!(:accept, object: subject)

      it "returns the accept activity" do
        expect(subject.accepted_or_rejected?).to eq(accept)
      end
    end

    context "when rejected" do
      let_create!(:reject, object: subject)

      it "returns the reject activity" do
        expect(subject.accepted_or_rejected?).to eq(reject)
      end
    end
  end

  context "validations" do
    let_build(:actor)
    let_build(:actor, named: :object, inbox: nil)

    it "validates the actor is local" do
      activity = subject.assign(actor: actor, object: object)
      expect(activity.valid_for_send?).to be_false
      expect(activity.errors["activity"]). to contain("actor must be local")
    end

    it "validates the object has an inbox" do
      activity = subject.assign(actor: actor, object: object)
      expect(activity.valid_for_send?).to be_false
      expect(activity.errors["activity"]). to contain("object must have an inbox")
    end

    it "passes validation" do
      actor.assign(iri: "https://test.test/actors/foo_bar")
      object.assign(iri: "https://remote/", inbox: "https://remote/inbox")
      activity = subject.assign(actor: actor, object: object)
      expect(activity.valid_for_send?).to be_true
      expect(activity.errors["activity"]?). to be_nil
    end
  end
end
