require "../../src/models/activity_pub"
require "../../src/models/activity_pub/actor/person"
require "../../src/models/activity_pub/collection"
require "../../src/models/activity_pub/object/note"

require "../spec_helper/model"
require "../spec_helper/factory"

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

class Foo < ActivityPubModel
  @[Assignable]
  property bar : Bar?
end

class Bar < ActivityPubModel
  @[Assignable]
  property foo : Foo?
end

Spectator.describe ActivityPub do
  setup_spec

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

    subject { Factory.create(:activity) }

    it "creates an instance if one doesn't exist" do
      json = %q[{"@id":"https://test.test/bar_foo","@type":"Activity"}]
      expect{described_class.from_json_ld(json).save}.to change{ActivityPub::Activity.count}.by(1)
    end

    it "updates the instance if it already exists" do
      json = %Q[{"@context":"https://www.w3.org/ns/activitystreams","@id":"#{subject.iri}","@type":"Activity","summary":"foo bar baz"}]
      expect{described_class.from_json_ld(json).save}.to change{ActivityPub::Activity.find(subject.iri).summary}
    end

    it "is defined on includers" do
      json = %q[{"@type":"ActivityPubModel"}]
      expect{ActivityPubModel.from_json_ld(json)}.to be_a(ActivityPubModel)
    end
  end

  describe ".from_json_ld?" do
    it "returns nil if type is not correct" do
      expect(Foo.from_json_ld?(%q[{"@type":"Bar"}])).to be_nil
    end
  end
end
