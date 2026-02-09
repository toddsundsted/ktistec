require "../../../../src/models/activity_pub/activity/reject"

require "../../../spec_helper/base"

Spectator.describe ActivityPub::Activity::Reject do
  setup_spec

  subject { described_class.new(iri: "http://test.test/#{random_string}").save }

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
end
