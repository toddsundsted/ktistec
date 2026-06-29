require "../../../../src/models/activity_pub/activity/update"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Activity::Update do
  setup_spec

  subject { described_class.new(iri: "http://test.test/#{random_string}").save }

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
end
