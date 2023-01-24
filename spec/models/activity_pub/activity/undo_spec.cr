require "../../../../src/models/activity_pub/activity/undo"
require "../../../../src/models/activity_pub/activity/follow"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Activity::Undo do
  setup_spec

  subject { described_class.new(iri: "http://test.test/#{random_string}") }

  describe "#actor" do
    it "returns an actor or actor subclass" do
      expect(typeof(subject.actor)).to eq({{(ActivityPub::Actor.all_subclasses << ActivityPub::Actor).join("|").id}})
    end
  end

  describe "#object" do
    it "returns a activity or activity subclass" do
      expect(typeof(subject.object)).to eq({{(ActivityPub::Activity.all_subclasses << ActivityPub::Activity).join("|").id}})
    end
  end

  context "validations" do
    let_build(:actor)
    let_build(:actor, named: :other)
    let_build(:follow, named: :object, actor: actor, object: other)

    it "validates the actor is the object's actor" do
      activity = subject.assign(actor: other, object: object)
      expect(activity.valid?).to be_false
      expect(activity.errors["activity"]). to contain("the actor must be the object's actor")
    end

    it "passes validation" do
      activity = subject.assign(actor: actor, object: object)
      expect(activity.valid?).to be_true
      expect(activity.errors["activity"]?). to be_nil
    end
  end
end
