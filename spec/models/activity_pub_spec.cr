require "../../src/models/activity_pub"
require "../../src/models/activity_pub/actor/person"
require "../../src/models/activity_pub/collection"
require "../../src/models/activity_pub/object/note"

require "../spec_helper/model"

module ActivityPub
  class ActivityPubModel
    include Ktistec::Model(Linked)
    include ActivityPub

    def save
      self
    end

    def self.find?(iri)
      nil
    end

    def self.map(json, **options)
      NamedTuple.new
    end
  end
end

class Foo < ActivityPub::ActivityPubModel
  @[Assignable]
  property bar : Bar?
end

class Bar < ActivityPub::ActivityPubModel
  @[Assignable]
  property foo : Foo?
end

Spectator.describe ActivityPub do
  setup_spec

  describe ".new" do
    it "instantiates nested models" do
      expect(Foo.new("bar.type": "Bar", "bar.iri": "bar").bar).to eq(Bar.new(iri: "bar"))
      expect(Bar.new("foo.type": "Foo", "foo.iri": "foo").foo).to eq(Foo.new(iri: "foo"))
    end
  end

  describe "#assign" do
    it "assigns nested models" do
      expect(Foo.new.assign("bar.type": "Bar", "bar.iri": "bar").bar).to eq(Bar.new(iri: "bar"))
      expect(Bar.new.assign("foo.type": "Foo", "foo.iri": "foo").foo).to eq(Foo.new(iri: "foo"))
    end
  end

  describe ".from_named_tuple" do
    it "raises an error if the type is not specified" do
      expect{described_class.from_named_tuple(**NamedTuple.new)}.to raise_error(NotImplementedError)
    end

    it "defaults the instance to the specified class" do
      expect(described_class.from_named_tuple(default: ActivityPub::Collection)).to be_a(ActivityPub::Collection)
    end

    it "raises an error if the type is not supported" do
      expect{described_class.from_named_tuple(type: "FooBar")}.to raise_error(NotImplementedError)
    end

    it "defaults the instance to the specified class" do
      expect(described_class.from_named_tuple(type: "FooBar", default: ActivityPub::Collection)).to be_a(ActivityPub::Collection)
    end

    it "instantiates the correct subclass" do
      expect(described_class.from_named_tuple(type: "ActivityPub::Actor::Person")).to be_a(ActivityPub::Actor::Person)
      expect(described_class.from_named_tuple(type: "ActivityPub::Object::Note")).to be_a(ActivityPub::Object::Note)
    end

    subject { ActivityPub::Activity.new(iri: "https://test.test/foo_bar").save }

    it "creates an instance if one doesn't exist" do
      options = {iri: "https://test.test/bar_foo", type: "ActivityPub::Activity"}
      expect{described_class.from_named_tuple(**options).save}.to change{ActivityPub::Activity.count}.by(1)
    end

    it "updates the instance if it already exists" do
      options = {iri: "https://test.test/foo_bar", type: "ActivityPub::Activity", summary: "foo bar baz"}
      expect{described_class.from_named_tuple(**options).save}.to change{ActivityPub::Activity.find(subject.iri).summary}
    end

    it "is defined on includers" do
      options = {type: "ActivityPub::ActivityPubModel"}
      expect{ActivityPub::ActivityPubModel.from_named_tuple(**options)}.to be_a(ActivityPub::ActivityPubModel)
    end
  end

  describe ".from_json_ld" do
    it "raises an error if the type is not specified" do
      expect{described_class.from_json_ld("{}")}.to raise_error(NotImplementedError)
    end

    it "defaults the instance to the specified class" do
      expect(described_class.from_json_ld("{}", default: ActivityPub::Collection)).to be_a(ActivityPub::Collection)
    end

    it "raises an error if the type is not supported" do
      expect{described_class.from_json_ld(%q[{"@type":"FooBar"}])}.to raise_error(NotImplementedError)
    end

    it "defaults the instance to the specified class" do
      expect(described_class.from_json_ld(%q[{"@type":"FooBar"}], default: ActivityPub::Collection)).to be_a(ActivityPub::Collection)
    end

    it "instantiates the correct subclass" do
      expect(described_class.from_json_ld(%q[{"@type":"Person"}])).to be_a(ActivityPub::Actor::Person)
      expect(described_class.from_json_ld(%q[{"@type":"Note"}])).to be_a(ActivityPub::Object::Note)
    end

    subject { ActivityPub::Activity.new(iri: "https://test.test/foo_bar").save }

    it "creates an instance if one doesn't exist" do
      json = %q[{"@id":"https://test.test/bar_foo","@type":"Activity"}]
      expect{described_class.from_json_ld(json).save}.to change{ActivityPub::Activity.count}.by(1)
    end

    it "updates the instance if it already exists" do
      json = %q[{"@context":"https://www.w3.org/ns/activitystreams","@id":"https://test.test/foo_bar","@type":"Activity","summary":"foo bar baz"}]
      expect{described_class.from_json_ld(json).save}.to change{ActivityPub::Activity.find(subject.iri).summary}
    end

    it "is defined on includers" do
      json = %q[{"@type":"ActivityPubModel"}]
      expect{ActivityPub::ActivityPubModel.from_json_ld(json)}.to be_a(ActivityPub::ActivityPubModel)
    end
  end
end
