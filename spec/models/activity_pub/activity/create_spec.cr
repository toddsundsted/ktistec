require "../../../spec_helper"

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
end
