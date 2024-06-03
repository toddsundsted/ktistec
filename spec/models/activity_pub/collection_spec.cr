require "../../../src/models/activity_pub/collection"

require "../../spec_helper/base"
require "../../spec_helper/factory"
require "../../spec_helper/network"

Spectator.describe ActivityPub::Collection do
  class ActivityPubModel
    include Ktistec::Model
    include ActivityPub

    @[Persistent]
    property iri : String

    def self.find?(iri, **options)
      nil
    end

    def self.map(json, **options)
      {"iri" => json.dig("@id").as_s}
    end
  end

  setup_spec

  context "when validating" do
    let!(collection) { described_class.new(iri: "http://test.test/foo_bar").save }

    it "must be an absolute URI" do
      expect(described_class.new(iri: "/some_collection").valid?).to be_false
    end

    it "must be unique" do
      expect(described_class.new(iri: "http://test.test/foo_bar").valid?).to be_false
    end

    it "is valid" do
      expect(described_class.new(iri: "http://test.test/#{random_string}").save.valid?).to be_true
    end
  end

  describe ".channel" do
    it "returns the channel" do
      expect(described_class.channel).to be_a(ModelChannel(ActivityPub::Collection))
    end
  end

  context "the channel" do
    # the `mock` keyword does not work with generic types
    Spectator::Mock.define_subtype(:class, ModelChannel(ActivityPub::Collection), MockChannel, publish: nil, subscribe: nil)

    let(channel) { MockChannel.new }

    before_each { ActivityPub::Collection.channel = channel }

    let_create(:collection, named: subject)

    describe "#notify_subscribers" do
      it "invokes publish on the channel" do
        subject.notify_subscribers
        expect(channel).to have_received(:publish)
      end
    end

    describe "#subscribe" do
      it "invokes subscribe on the channel" do
        subject.subscribe {}
        expect(channel).to have_received(:subscribe)
      end
    end
  end

  let(model) { ActivityPubModel.new(iri: "item link") }

  let(json) do
    <<-JSON
      {
        "@context":[
          "https://www.w3.org/ns/activitystreams"
        ],
        "@id":"https://test.test/foo_bar",
        "totalItems":0,
        "first":"first link",
        "last":"last link",
        "prev":"prev link",
        "next":"next link",
        "current":"current link"
      }
    JSON
  end

  describe ".from_json_ld" do
    it "creates a new instance" do
      collection = described_class.from_json_ld(json).save
      expect(collection.iri).to eq("https://test.test/foo_bar")
      expect(collection.total_items).to eq(0)
      expect(collection.first_iri).to eq("first link")
      expect(collection.last_iri).to eq("last link")
      expect(collection.prev_iri).to eq("prev link")
      expect(collection.next_iri).to eq("next link")
      expect(collection.current_iri).to eq("current link")
    end

    it "extracts items identifiers" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "items":[
            "item link"
          ]
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.items_iris).to eq(["item link"])
      expect(collection.items).to eq(["item link"])
    end

    it "extracts items identifiers" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "items":[
            {
              "type":"ActivityPubModel",
              "id":"item link"
            }
          ]
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.items_iris).to eq(["item link"])
      expect(collection.items).to eq([model])
    end

    it "handles ordered items" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "orderedItems":[
            {
              "type":"ActivityPubModel",
              "id":"item link"
            }
          ]
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.items_iris).to eq(["item link"])
      expect(collection.items).to eq([model])
    end

    it "handles embedded first" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "first":{
            "items":[
              "item link"
            ]
          }
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.first).to be_a(ActivityPub::Collection)
      expect(collection.first.not_nil!.items_iris).to eq(["item link"])
    end

    it "handles embedded last" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "last":{
            "items":[
              "item link"
            ]
          }
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.last).to be_a(ActivityPub::Collection)
      expect(collection.last.not_nil!.items_iris).to eq(["item link"])
    end

    it "handles embedded prev" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "prev":{
            "items":[
              "item link"
            ]
          }
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.prev).to be_a(ActivityPub::Collection)
      expect(collection.prev.not_nil!.items_iris).to eq(["item link"])
    end

    it "handles embedded next" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "next":{
            "items":[
              "item link"
            ]
          }
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.next).to be_a(ActivityPub::Collection)
      expect(collection.next.not_nil!.items_iris).to eq(["item link"])
    end

    it "handles embedded current" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "current":{
            "items":[
              "item link"
            ]
          }
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.current).to be_a(ActivityPub::Collection)
      expect(collection.current.not_nil!.items_iris).to eq(["item link"])
    end

    it "raises an error" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "items":[
            []
          ]
        }
      JSON
      expect{described_class.from_json_ld(json)}.to raise_error(TypeCastError)
    end
  end

  describe "#from_json_ld" do
    it "updates an existing instance" do
      collection = described_class.new.from_json_ld(json).save
      expect(collection.iri).to eq("https://test.test/foo_bar")
      expect(collection.total_items).to eq(0)
      expect(collection.first_iri).to eq("first link")
      expect(collection.last_iri).to eq("last link")
      expect(collection.prev_iri).to eq("prev link")
      expect(collection.next_iri).to eq("next link")
      expect(collection.current_iri).to eq("current link")
    end

    it "extracts items identifiers" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "items":[
            "item link"
          ]
        }
      JSON
      collection = described_class.new.from_json_ld(json).save
      expect(collection.items_iris).to eq(["item link"])
      expect(collection.items).to eq(["item link"])
    end

    it "extracts items identifiers" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "items":[
            {
              "type":"ActivityPubModel",
              "id":"item link"
            }
          ]
        }
      JSON
      collection = described_class.new.from_json_ld(json).save
      expect(collection.items_iris).to eq(["item link"])
      expect(collection.items).to eq([model])
    end

    it "handles ordered items" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "orderedItems":[
            {
              "type":"ActivityPubModel",
              "id":"item link"
            }
          ]
        }
      JSON
      collection = described_class.new.from_json_ld(json).save
      expect(collection.items_iris).to eq(["item link"])
      expect(collection.items).to eq([model])
    end

    it "handles embedded first" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "first":{
            "items":[
              "item link"
            ]
          }
        }
      JSON
      collection = described_class.new.from_json_ld(json).save
      expect(collection.first).to be_a(ActivityPub::Collection)
      expect(collection.first.not_nil!.items_iris).to eq(["item link"])
    end

    it "handles embedded last" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "last":{
            "items":[
              "item link"
            ]
          }
        }
      JSON
      collection = described_class.new.from_json_ld(json).save
      expect(collection.last).to be_a(ActivityPub::Collection)
      expect(collection.last.not_nil!.items_iris).to eq(["item link"])
    end

    it "handles embedded prev" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "prev":{
            "items":[
              "item link"
            ]
          }
        }
      JSON
      collection = described_class.new.from_json_ld(json).save
      expect(collection.prev).to be_a(ActivityPub::Collection)
      expect(collection.prev.not_nil!.items_iris).to eq(["item link"])
    end

    it "handles embedded next" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "next":{
            "items":[
              "item link"
            ]
          }
        }
      JSON
      collection = described_class.new.from_json_ld(json).save
      expect(collection.next).to be_a(ActivityPub::Collection)
      expect(collection.next.not_nil!.items_iris).to eq(["item link"])
    end

    it "handles embedded current" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "current":{
            "items":[
              "item link"
            ]
          }
        }
      JSON
      collection = described_class.new.from_json_ld(json).save
      expect(collection.current).to be_a(ActivityPub::Collection)
      expect(collection.current.not_nil!.items_iris).to eq(["item link"])
    end

    it "raises an error" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "items":[
            []
          ]
        }
      JSON
      expect{described_class.new.from_json_ld(json)}.to raise_error(TypeCastError)
    end
  end

  describe "#to_json_ld" do
    it "renders an identical instance" do
      collection = described_class.from_json_ld(json)
      expect(described_class.from_json_ld(collection.to_json_ld)).to eq(collection)
    end

    subject { described_class.new(iri: "https://remote/#{random_string}") }

    it "embeds first" do
      subject.first = described_class.new(iri: "https://remote/first")
      expect(JSON.parse(subject.to_json_ld(recursive: true)).dig("first", "id")).to eq("https://remote/first")
    end

    it "embeds last" do
      subject.last = described_class.new(iri: "https://remote/last")
      expect(JSON.parse(subject.to_json_ld(recursive: true)).dig("last", "id")).to eq("https://remote/last")
    end

    it "embeds prev" do
      subject.prev = described_class.new(iri: "https://remote/prev")
      expect(JSON.parse(subject.to_json_ld(recursive: true)).dig("prev", "id")).to eq("https://remote/prev")
    end

    it "embeds next" do
      subject.next = described_class.new(iri: "https://remote/next")
      expect(JSON.parse(subject.to_json_ld(recursive: true)).dig("next", "id")).to eq("https://remote/next")
    end

    it "embeds current" do
      subject.current = described_class.new(iri: "https://remote/current")
      expect(JSON.parse(subject.to_json_ld(recursive: true)).dig("current", "id")).to eq("https://remote/current")
    end

    it "embeds local item" do
      subject.items = [described_class.new(iri: "https://test.test/item").as(ActivityPub | String)]
      expect(JSON.parse(subject.to_json_ld(recursive: true)).dig("items", 0, "id")).to eq("https://test.test/item")
    end

    it "links remote item" do
      subject.items = [described_class.new(iri: "https://remote/item").as(ActivityPub | String)]
      expect(JSON.parse(subject.to_json_ld(recursive: true)).dig("items", 0)).to eq("https://remote/item")
    end

    it "links item" do
      subject.items = ["https://remote/item".as(ActivityPub | String)]
      expect(JSON.parse(subject.to_json_ld(recursive: true)).dig("items", 0)).to eq("https://remote/item")
    end

    it "links item" do
      subject.items_iris = ["https://remote/item"]
      expect(JSON.parse(subject.to_json_ld).dig("items", 0)).to eq("https://remote/item")
    end
  end

  describe "#all_item_iris" do
    let_create(:actor, named: :source, with_keys: true)

    it "returns nil" do
      expect(described_class.new.all_item_iris(source)).to be_nil
    end

    context "given a collection with items" do
      subject { described_class.new(items_iris: ["https://remote/item"]) }

      it "returns the items" do
        expect(subject.all_item_iris(source)).to eq(["https://remote/item"])
      end
    end

    context "given a collection paginated with first and next" do
      let(next2) { described_class.new(iri: "https://remote/next2", items_iris: ["https://remote/item3"]) }
      let(next1) { described_class.new(iri: "https://remote/next1", next_iri: next2.iri, items_iris: ["https://remote/item2"]) }
      let(first) { described_class.new(iri: "https://remote/first", next_iri: next1.iri, items_iris: ["https://remote/item1"]) }
      subject { described_class.new(first_iri: first.iri) }

      before_each do
        HTTP::Client.collections << next2
        HTTP::Client.collections << next1
        HTTP::Client.collections << first
      end

      it "fetches the collections" do
        subject.all_item_iris(source)
        expect(HTTP::Client.requests).to have("GET #{first.iri}", "GET #{next1.iri}", "GET #{next2.iri}")
      end

      it "returns the items" do
        expect(subject.all_item_iris(source).as(Array(String))).to have("https://remote/item1", "https://remote/item2", "https://remote/item3")
      end
    end

    context "given a collection paginated with last and prev" do
      let(prev2) { described_class.new(iri: "https://remote/prev2", items_iris: ["https://remote/item3"]) }
      let(prev1) { described_class.new(iri: "https://remote/prev1", prev_iri: prev2.iri, items_iris: ["https://remote/item2"]) }
      let(last) { described_class.new(iri: "https://remote/last", prev_iri: prev1.iri, items_iris: ["https://remote/item1"]) }
      subject { described_class.new(last_iri: last.iri) }

      before_each do
        HTTP::Client.collections << prev2
        HTTP::Client.collections << prev1
        HTTP::Client.collections << last
      end

      it "fetches the collections" do
        subject.all_item_iris(source)
        expect(HTTP::Client.requests).to have("GET #{last.iri}", "GET #{prev1.iri}", "GET #{prev2.iri}")
      end

      it "returns the items" do
        expect(subject.all_item_iris(source).as(Array(String))).to have("https://remote/item1", "https://remote/item2", "https://remote/item3")
      end
    end
  end
end
