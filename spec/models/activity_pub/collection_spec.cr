require "../../../src/models/activity_pub/collection"

require "../../spec_helper/base"

Spectator.describe ActivityPub::Collection do
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
      expect(collection.first).to eq("first link")
      expect(collection.last).to eq("last link")
      expect(collection.prev).to eq("prev link")
      expect(collection.next).to eq("next link")
      expect(collection.current).to eq("current link")
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
              "id":"item link"
            }
          ]
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.items_iris).to eq(["item link"])
      expect(collection.items).to eq([{"@id" => "item link"}])
    end

    it "handles ordered items" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "orderedItems":[
            {
              "id":"item link"
            }
          ]
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.items_iris).to eq(["item link"])
      expect(collection.items).to eq([{"@id" => "item link"}])
    end
  end

  describe "#from_json_ld" do
    it "updates an existing instance" do
      collection = described_class.new.from_json_ld(json).save
      expect(collection.iri).to eq("https://test.test/foo_bar")
      expect(collection.total_items).to eq(0)
      expect(collection.first).to eq("first link")
      expect(collection.last).to eq("last link")
      expect(collection.prev).to eq("prev link")
      expect(collection.next).to eq("next link")
      expect(collection.current).to eq("current link")
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
              "id":"item link"
            }
          ]
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.items_iris).to eq(["item link"])
      expect(collection.items).to eq([{"@id" => "item link"}])
    end

    it "handles ordered items" do
      json = <<-JSON
        {
          "@context":"https://www.w3.org/ns/activitystreams",
          "@id":"https://test.test/foo_bar",
          "orderedItems":[
            {
              "id":"item link"
            }
          ]
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.items_iris).to eq(["item link"])
      expect(collection.items).to eq([{"@id" => "item link"}])
    end
  end

  describe "#to_json_ld" do
    it "renders an identical instance" do
      collection = described_class.from_json_ld(json)
      expect(described_class.from_json_ld(collection.to_json_ld)).to eq(collection)
    end
  end
end
