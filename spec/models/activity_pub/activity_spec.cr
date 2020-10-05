require "../../spec_helper"

class FooBarActivity < ActivityPub::Activity
  belongs_to actor, class_name: ActivityPub::Actor, foreign_key: actor_iri, primary_key: iri
  belongs_to object, class_name: ActivityPub::Object, foreign_key: object_iri, primary_key: iri
  belongs_to target, class_name: ActivityPub::Activity, foreign_key: target_iri, primary_key: iri
end

Spectator.describe ActivityPub::Activity do
  setup_spec

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

  describe "#local" do
    it "indicates if the activity is local" do
      expect(described_class.new(iri: "https://test.test/foo_bar").local).to be_true
      expect(described_class.new(iri: "https://remote/foo_bar").local).to be_false
    end
  end
end
