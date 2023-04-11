require "../../../src/models/activity_pub/collection"

require "../../spec_helper/base"

Spectator.describe ActivityPub::Collection do
  class ActivityPubModel
    include Ktistec::Model(Nil)
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

    it "must be present" do
      expect(described_class.new.valid?).to be_false
    end

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
end
