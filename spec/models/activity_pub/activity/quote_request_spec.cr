require "../../../../src/models/activity_pub/activity/quote_request"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe ActivityPub::Activity::QuoteRequest do
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

  describe "#instrument" do
    it "returns an object or object subclass" do
      expect(typeof(subject.instrument)).to eq({{(ActivityPub::Object.all_subclasses << ActivityPub::Object).join("|").id}})
    end
  end
end
