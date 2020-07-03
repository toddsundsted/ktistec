require "../../spec_helper"

class FooBarActivity < ActivityPub::Activity
end

Spectator.describe ActivityPub::Activity do
  before_each { Balloon.database.exec "BEGIN TRANSACTION" }
  after_each { Balloon.database.exec "ROLLBACK" }

  context "when validating" do
    let!(activity) { described_class.new(iri: "https://test.test/foo_bar").save }

    it "must be present" do
      expect(described_class.new.valid?).to be_false
    end

    it "must be an absolute URI" do
      expect(described_class.new(iri: "/some_activity").valid?).to be_false
    end

    it "must be unique" do
      expect(described_class.new(iri: "https://test.test/foo_bar").valid?).to be_false
    end

    it "is valid" do
      expect(described_class.new(iri: "https://test.test/#{random_string}").save.valid?).to be_true
    end

    it "may not be visible if remote" do
      expect(described_class.new(iri: "https://remote/0", visible: true).valid?).to be_false
    end
  end

  let(json) do
    <<-JSON
      {
        "@context":[
          "https://www.w3.org/ns/activitystreams"
        ],
        "@id":"https://test.test/foo_bar",
        "@type":"FooBarActivity",
        "published":"2016-02-15T10:20:30Z",
        "actor":"actor link",
        "object":{
          "id":"object link"
        },
        "target":{
          "id":"target link"
        },
        "to":"to link",
        "cc":["cc link"],
        "summary":"abc"
      }
    JSON
  end

  describe ".from_json_ld" do
    it "instantiates the subclass" do
      activity = described_class.from_json_ld(json)
      expect(activity.class).to eq(FooBarActivity)
    end

    it "creates a new instance" do
      activity = described_class.from_json_ld(json).save
      expect(activity.iri).to eq("https://test.test/foo_bar")
      expect(activity.published).to eq(Time.utc(2016, 2, 15, 10, 20, 30))
      expect(activity.actor_iri).to eq("actor link")
      expect(activity.object_iri).to eq("object link")
      expect(activity.target_iri).to eq("target link")
      expect(activity.to).to eq(["to link"])
      expect(activity.cc).to eq(["cc link"])
      expect(activity.summary).to eq("abc")
    end
  end

  describe "#from_json_ld" do
    it "updates an existing instance" do
      activity = described_class.new.from_json_ld(json).save
      expect(activity.iri).to eq("https://test.test/foo_bar")
      expect(activity.published).to eq(Time.utc(2016, 2, 15, 10, 20, 30))
      expect(activity.actor_iri).to eq("actor link")
      expect(activity.object_iri).to eq("object link")
      expect(activity.target_iri).to eq("target link")
      expect(activity.to).to eq(["to link"])
      expect(activity.cc).to eq(["cc link"])
      expect(activity.summary).to eq("abc")
    end
  end

  describe "#to_json_ld" do
    it "renders an identical instance" do
      activity = described_class.from_json_ld(json)
      expect(described_class.from_json_ld(activity.to_json_ld)).to eq(activity)
    end
  end
end
