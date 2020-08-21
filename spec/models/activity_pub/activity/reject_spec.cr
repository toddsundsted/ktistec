require "../../../spec_helper"

Spectator.describe ActivityPub::Activity::Reject do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  subject { described_class.new(iri: "http://test.test/#{random_string}").save }

  describe "#actor" do
    it "returns an actor or actor subclass" do
      expect(typeof(subject.actor)).to eq({{(ActivityPub::Actor.all_subclasses << ActivityPub::Actor).join("|").id}})
    end
  end

  describe "#object" do
    it "returns a follow or follow subclass" do
      expect(typeof(subject.object)).to eq({{(ActivityPub::Activity::Follow.all_subclasses << ActivityPub::Activity::Follow).join("|").id}})
    end
  end
end
