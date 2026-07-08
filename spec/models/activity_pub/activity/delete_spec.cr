require "../../../../src/models/activity_pub/activity/delete"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Activity::Delete do
  setup_spec

  subject { described_class.new(iri: "http://test.test/#{random_string}") }

  describe "#actor" do
    it "returns an actor or actor subclass" do
      expect(typeof(subject.actor)).to eq({{(ActivityPub::Actor.all_subclasses << ActivityPub::Actor).join("|").id}})
    end
  end

  describe "#object" do
    it "returns an actor, object or one of their subclasses" do
      expect(typeof(subject.object)).to eq({{((ActivityPub::Actor.all_subclasses + ActivityPub::Object.all_subclasses) << ActivityPub::Actor << ActivityPub::Object).join("|").id}})
    end
  end

  describe "#to_json_ld" do
    let_build(:delete)

    subject { JSON.parse(delete.to_json_ld) }

    it "doesn't recursively serialize the actor" do
      expect(subject.dig("actor").as_s?).to be_truthy
    end

    it "doesn't recursively serialize the object" do
      expect(subject.dig("object").as_s?).to be_truthy
    end
  end
end
