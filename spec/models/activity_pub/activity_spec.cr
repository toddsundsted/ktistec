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
        "audience":["audience link"],
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
      expect(activity.audience).to eq(["audience link"])
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
      expect(activity.audience).to eq(["audience link"])
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

    context "when audience is multiple values" do
      before_each { activity.audience = ["audience link 1", "audience link 2"] }

      it "renders audience as an array" do
        json = JSON.parse(activity.to_json_ld)
        expect(json["audience"].as_a?).to be_truthy
      end
    end

    context "when audience is a single value" do
      before_each { activity.audience = ["audience link"] }

      it "renders audience as a string" do
        json = JSON.parse(activity.to_json_ld)
        expect(json["audience"].as_s?).to be_truthy
      end
    end
  end
end

Spectator.describe ActivityPub::Activity::ModelHelper do
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

  describe ".from_json_ld" do
    let(activity) { described_class.from_json_ld(json) }

    it "populates actor_iri" do
      expect(activity["actor_iri"]).to eq("actor link")
    end

    it "does not populate actor" do
      expect(activity.has_key?("actor")).to be_false
    end

    context "given an actor with the same host" do
      let(json) { super.gsub(%q|"id":"actor link"|, %q|"id":"https://test.test/actor"|) }

      it "populates actor" do
        expect(activity["actor"]).to be_a(ActivityPub::Actor)
        expect(activity["actor"].as(ActivityPub::Actor).iri).to eq("https://test.test/actor")
      end
    end

    it "populates object_iri" do
      expect(activity["object_iri"]).to eq("object link")
    end

    it "does not populate object" do
      expect(activity.has_key?("object")).to be_false
    end

    context "given an object with the same host" do
      let(json) { super.gsub(%q|"@id":"object link"|, %q|"@id":"https://test.test/object"|) }

      it "populates object" do
        expect(activity["object"]).to be_a(ActivityPub::Object)
        expect(activity["object"].as(ActivityPub::Object).iri).to eq("https://test.test/object")
      end
    end

    it "populates target_iri" do
      expect(activity["target_iri"]).to eq("target link")
    end

    it "does not populate target" do
      expect(activity.has_key?("target")).to be_false
    end

    context "given a target with the same host" do
      let(json) { super.gsub(%q|"@id":"target link"|, %q|"@id":"https://test.test/target"|) }

      it "populates target" do
        expect(activity["target"]).to be_a(ActivityPub::Activity)
        expect(activity["target"].as(ActivityPub::Activity).iri).to eq("https://test.test/target")
      end
    end
  end
end
