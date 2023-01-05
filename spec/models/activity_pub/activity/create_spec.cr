require "../../../../src/models/activity_pub/activity/create"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Activity::Create do
  setup_spec

  subject { described_class.new(iri: "http://test.test/#{random_string}").save }

  describe "#actor" do
    it "returns an actor or actor subclass" do
      expect(typeof(subject.actor)).to eq({{(ActivityPub::Actor.all_subclasses << ActivityPub::Actor).join("|").id}})
    end
  end

  describe "#object" do
    it "returns an object or object subclass" do
      expect(typeof(subject.object)).to eq({{(ActivityPub::Object.all_subclasses << ActivityPub::Object).join("|").id}})
    end
  end

  context "validations" do
    let_build(:actor)
    let_build(:object)

    it "validates the actor is local" do
      activity = subject.assign(actor: actor, object: object)
      expect(activity.valid_for_send?).to be_false
      expect(activity.errors["activity"]). to contain("actor must be local")
    end

    it "validates the object is attributed to the actor" do
      activity = subject.assign(actor: actor, object: object)
      expect(activity.valid_for_send?).to be_false
      expect(activity.errors["activity"]). to contain("object must be attributed to actor")
    end

    it "passes validation" do
      actor.assign(iri: "https://test.test/actors/foo_bar")
      object.assign(iri: "https://test.test/objects/foo_bar", attributed_to: actor)
      activity = subject.assign(actor: actor, object: object)
      expect(activity.valid_for_send?).to be_true
      expect(activity.errors["activity"]?). to be_nil
    end
  end
end
