require "../../../../src/models/activity_pub/activity/like"

require "../../../spec_helper/base"

Spectator.describe ActivityPub::Activity::Like do
  setup_spec

  subject { described_class.new(iri: "http://test.test/#{random_string}") }

  describe "#actor" do
    it "returns an actor or actor subclass" do
      expect(typeof(subject.actor)).to eq({{(ActivityPub::Actor.all_subclasses << ActivityPub::Actor).join("|").id}})
    end
  end

  describe "#object" do
    it "returns a object or object subclass" do
      expect(typeof(subject.object)).to eq({{(ActivityPub::Object.all_subclasses << ActivityPub::Object).join("|").id}})
    end
  end
end
