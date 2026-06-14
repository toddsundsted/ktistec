require "../../src/models/activity_pub"
require "../../src/models/activity_pub/actor/person"
require "../../src/models/activity_pub/collection"
require "../../src/models/activity_pub/object/note"

require "../spec_helper/base"
require "../spec_helper/factory"

Spectator.describe ActivityPub do
  setup_spec

  describe ".from_json_ld" do
    it "raises an error if the type is not specified" do
      expect { described_class.from_json_ld("{}") }.to raise_error(NotImplementedError)
    end

    it "defaults the instance to the specified class" do
      expect(described_class.from_json_ld("{}", default: ActivityPub::Collection)).to be_a(ActivityPub::Collection)
    end

    it "raises an error if the type is not supported" do
      expect { described_class.from_json_ld(%q[{"@type":"FooBar"}]) }.to raise_error(NotImplementedError)
    end

    it "defaults the instance to the specified class" do
      expect(described_class.from_json_ld(%q[{"@type":"FooBar"}], default: ActivityPub::Collection)).to be_a(ActivityPub::Collection)
    end

    it "instantiates the correct subclass" do
      expect(described_class.from_json_ld(%q[{"@type":"Person"}])).to be_a(ActivityPub::Actor::Person)
      expect(described_class.from_json_ld(%q[{"@type":"Note"}])).to be_a(ActivityPub::Object::Note)
    end

    context "given aliases" do
      pre_condition do
        expect(ActivityPub::Actor::ALIASES).to have("ActivityPub::Actor::Organization")
        expect(ActivityPub::Object::ALIASES).to have("ActivityPub::Object::Place")
      end

      it "instantiates the base class" do
        expect(described_class.from_json_ld(%q[{"@type":"Organization"}])).to be_a(ActivityPub::Actor)
        expect(described_class.from_json_ld(%q[{"@type":"Place"}])).to be_a(ActivityPub::Object)
      end

      it "persists the correct type" do
        actor = described_class.from_json_ld(%q[{"@type":"Organization"}]).as(ActivityPub::Actor)
        expect(actor.type).to eq("ActivityPub::Actor::Organization")
      end

      it "persists the correct type" do
        object = described_class.from_json_ld(%q[{"@type":"Place"}]).as(ActivityPub::Object)
        expect(object.type).to eq("ActivityPub::Object::Place")
      end
    end

    let_create(:activity)

    it "creates an instance if one doesn't exist" do
      json = %q[{"@id":"https://test.test/bar_foo","@type":"Activity"}]
      expect { described_class.from_json_ld(json).save }.to change { ActivityPub::Activity.count }.by(1)
    end

    it "updates the instance if it already exists" do
      json = %Q[{"@context":"https://www.w3.org/ns/activitystreams","@id":"#{activity.iri}","@type":"Activity","summary":"foo bar baz"}]
      expect { described_class.from_json_ld(json).save }.to change { activity.reload!.summary }
    end
  end

  describe ".from_json_ld?" do
    it "returns nil if the type is not specified" do
      expect(described_class.from_json_ld?("{}")).to be_nil
    end

    it "returns nil if the type is not supported" do
      expect(described_class.from_json_ld?(%q[{"@type":"FooBar"}])).to be_nil
    end
  end

  def expand_as(body)
    Ktistec::JSON_LD.expand(JSON.parse(%<{"@context":"https://www.w3.org/ns/activitystreams",#{body}}>))
  end

  describe ".dig_text?" do
    let(name) { "https://www.w3.org/ns/activitystreams#name" }

    context "given no value" do
      let(json) { expand_as(%<"@type":"Note">) }

      it "returns nil" do
        expect(described_class.dig_text?(json, name)).to be_nil
      end
    end

    context "given a plain string value" do
      let(json) { expand_as(%<"name":"Foo Bar Baz">) }

      it "returns the value" do
        expect(described_class.dig_text?(json, name)).to eq("Foo Bar Baz")
      end
    end

    context "given a language map without an undetermined entry" do
      let(json) { expand_as(%<"nameMap":{"fr":"Foo Bàr Bàz"}>) }

      it "returns a tagged entry" do
        expect(described_class.dig_text?(json, name)).to eq("Foo Bàr Bàz")
      end
    end

    context "given both a plain string and a language map" do
      let(json) { expand_as(%<"name":"Foo Bar Baz","nameMap":{"fr":"Foo Bàr Bàz"}>) }

      it "prefers the undetermined entry" do
        expect(described_class.dig_text?(json, name)).to eq("Foo Bar Baz")
      end
    end

    context "given a value object" do
      let(json) { expand_as(%<"name":{"@value":"Foo Bar Baz","@language":"en"}>) }

      it "returns the value" do
        expect(described_class.dig_text?(json, name)).to eq("Foo Bar Baz")
      end
    end

    context "given a sender-arrayed plain string" do
      let(json) { expand_as(%<"name":["Foo Bar Baz"]>) }

      it "returns the value" do
        expect(described_class.dig_text?(json, name)).to eq("Foo Bar Baz")
      end
    end
  end
end
