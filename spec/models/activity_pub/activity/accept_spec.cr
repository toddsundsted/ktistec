require "../../../spec_helper"

Spectator.describe ActivityPub::Activity::Accept do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  subject { described_class.new(iri: "http://test.test/#{random_string}").save }

  describe "#actor" do
    it "returns an actor" do
      expect(typeof(subject.actor)).to eq(ActivityPub::Actor)
    end
  end

  describe "#object" do
    it "returns an activity" do
      expect(typeof(subject.object)).to eq(ActivityPub::Activity)
    end
  end
end
