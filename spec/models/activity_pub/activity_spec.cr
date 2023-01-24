require "../../../src/models/activity_pub/activity"
require "../../../src/models/activity_pub/object"

require "../../spec_helper/base"
require "../../spec_helper/factory"

class FooBarActivity < ActivityPub::Activity
  belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri
  belongs_to target, class_name: ActivityPub::Activity, foreign_key: target_iri, primary_key: iri
end

Spectator.describe ActivityPub::Activity do
  setup_spec

  context "when validating" do
    it "is valid" do
      expect(described_class.new(iri: "https://test.test/#{random_string}").valid?).to be_true
    end
  end

  context "given embedded objects" do
    let(json) do
      <<-JSON
        {
          "@context":[
            "https://www.w3.org/ns/activitystreams"
          ],
          "@id":"https://test.test/foo_bar",
          "@type":"FooBarActivity",
          "actor":{
            "id":"actor link",
            "type":"Actor"
          },
          "object":{
            "@id":"object link",
            "@type":"Object"
          },
          "target":{
            "@id":"target link",
            "@type":"Activity"
          }
        }
      JSON
    end

    it "caches the actor" do
      activity = described_class.from_json_ld(json).as(FooBarActivity)
      expect(activity.actor).to be_a(ActivityPub::Actor)
      expect(activity.actor.iri).to eq("actor link")
    end

    it "caches the object" do
      activity = described_class.from_json_ld(json).as(FooBarActivity)
      expect(activity.object).to be_a(ActivityPub::Object)
      expect(activity.object.iri).to eq("object link")
    end

    it "caches the target" do
      activity = described_class.from_json_ld(json).as(FooBarActivity)
      expect(activity.target).to be_a(ActivityPub::Activity)
      expect(activity.target.iri).to eq("target link")
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
        "object":"object link",
        "target":"target link",
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

    context "when addressed to the public collection" do
      it "is visible" do
        json = self.json.gsub("to link", "https://www.w3.org/ns/activitystreams#Public")
        activity = described_class.from_json_ld(json).save
        expect(activity.visible).to be_true
      end
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

    context "when addressed to the public collection" do
      it "is visible" do
        json = self.json.gsub("cc link", "https://www.w3.org/ns/activitystreams#Public")
        activity = described_class.new.from_json_ld(json).save
        expect(activity.visible).to be_true
      end
    end
  end

  describe "#to_json_ld" do
    it "renders an identical instance" do
      activity = described_class.from_json_ld(json)
      expect(described_class.from_json_ld(activity.to_json_ld)).to eq(activity)
    end

    let(activity) do
      FooBarActivity.new(
        actor: Factory.build(:actor),
        object: Factory.build(:object),
        target: Factory.build(:activity)
      )
    end

    it "renders object and target recursively by default" do
      json = JSON.parse(activity.to_json_ld)
      expect(json["actor"].as_s?).to be_truthy
      expect(json["object"].as_h?).to be_truthy
      expect(json["target"].as_h?).to be_truthy
    end

    it "renders everything recursively if true" do
      json = JSON.parse(activity.to_json_ld(recursive: true))
      expect(json["actor"].as_h?).to be_truthy
      expect(json["object"].as_h?).to be_truthy
      expect(json["target"].as_h?).to be_truthy
    end

    it "renders nothing recursively if false" do
      json = JSON.parse(activity.to_json_ld(recursive: false))
      expect(json["actor"].as_s?).to be_truthy
      expect(json["object"].as_s?).to be_truthy
      expect(json["target"].as_s?).to be_truthy
    end
  end
end
