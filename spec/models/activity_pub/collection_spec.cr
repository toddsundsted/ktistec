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

  let(model) { ActivityPubModel.new(iri: "https://test.test/item") }

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
              "id":"https://test.test/item"
            }
          ]
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.items_iris).to eq(["https://test.test/item"])
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
              "id":"https://test.test/item"
            }
          ]
        }
      JSON
      collection = described_class.from_json_ld(json).save
      expect(collection.items_iris).to eq(["https://test.test/item"])
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
      expect { described_class.from_json_ld(json) }.to raise_error(TypeCastError)
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
              "id":"https://test.test/item"
            }
          ]
        }
      JSON
      collection = described_class.new.from_json_ld(json).save
      expect(collection.items_iris).to eq(["https://test.test/item"])
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
              "id":"https://test.test/item"
            }
          ]
        }
      JSON
      collection = described_class.new.from_json_ld(json).save
      expect(collection.items_iris).to eq(["https://test.test/item"])
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
      expect { described_class.new.from_json_ld(json) }.to raise_error(TypeCastError)
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

Spectator.describe ActivityPub::Collection::ModelHelper do
  let(json) do
    <<-JSON
      {
        "@context":[
          "https://www.w3.org/ns/activitystreams"
        ],
        "@id":"https://test.test/foo_bar",
        "totalItems":0,
        "first":{
          "id":"first link",
          "@type":"Collection"
        },
        "last":{
          "id":"last link",
          "@type":"Collection"
        },
        "prev":{
          "id":"prev link",
          "@type":"Collection"
        },
        "next":{
          "id":"next link",
          "@type":"Collection"
        },
        "current":{
          "id":"current link",
          "@type":"Collection"
        }
      }
    JSON
  end

  describe ".from_json_ld" do
    let(activity) { described_class.from_json_ld(json) }

    context "first tests" do
      it "populates first_iri" do
        expect(activity["first_iri"]).to eq("first link")
      end

      it "does not populate first" do
        expect(activity.has_key?("first")).to be_false
      end

      context "given first with the same host" do
        let(json) { super.gsub(%q|"id":"first link",|, %q|"id":"https://test.test/first",|) }

        it "populates first" do
          expect(activity["first"]).to be_a(ActivityPub::Collection)
          expect(activity["first"].as(ActivityPub::Collection).iri).to eq("https://test.test/first")
        end
      end

      context "given collection without an id" do
        let(json) { super.gsub(%q|"id":"first link",|, %q|"id":"https://test.test/first",|).gsub(%q|"@id":"https://test.test/foo_bar",|, "") }

        it "does not populate first" do
          expect(activity.has_key?("first")).to be_false
        end
      end

      context "given first with a different host" do
        let(json) { super.gsub(%q|"id":"first link",|, %q|"id":"https://different/first",|) }

        it "does not populate first" do
          expect(activity.has_key?("first")).to be_false
        end
      end

      context "given first without an id" do
        let(json) { super.gsub(%q|"id":"first link",|, "") }

        it "populates first" do
          expect(activity["first"]).to be_a(ActivityPub::Collection)
        end
      end
    end

    context "last tests" do
      it "populates last_iri" do
        expect(activity["last_iri"]).to eq("last link")
      end

      it "does not populate last" do
        expect(activity.has_key?("last")).to be_false
      end

      context "given last with the same host" do
        let(json) { super.gsub(%q|"id":"last link",|, %q|"id":"https://test.test/last",|) }

        it "populates last" do
          expect(activity["last"]).to be_a(ActivityPub::Collection)
          expect(activity["last"].as(ActivityPub::Collection).iri).to eq("https://test.test/last")
        end
      end

      context "given collection without an id" do
        let(json) { super.gsub(%q|"id":"last link",|, %q|"id":"https://test.test/last",|).gsub(%q|"@id":"https://test.test/foo_bar",|, "") }

        it "does not populate last" do
          expect(activity.has_key?("last")).to be_false
        end
      end

      context "given last with a different host" do
        let(json) { super.gsub(%q|"id":"last link",|, %q|"id":"https://different/last",|) }

        it "does not populate last" do
          expect(activity.has_key?("last")).to be_false
        end
      end

      context "given last without an id" do
        let(json) { super.gsub(%q|"id":"last link",|, "") }

        it "populates last" do
          expect(activity["last"]).to be_a(ActivityPub::Collection)
        end
      end
    end

    context "prev tests" do
      it "populates prev_iri" do
        expect(activity["prev_iri"]).to eq("prev link")
      end

      it "does not populate prev" do
        expect(activity.has_key?("prev")).to be_false
      end

      context "given prev with the same host" do
        let(json) { super.gsub(%q|"id":"prev link",|, %q|"id":"https://test.test/prev",|) }

        it "populates prev" do
          expect(activity["prev"]).to be_a(ActivityPub::Collection)
          expect(activity["prev"].as(ActivityPub::Collection).iri).to eq("https://test.test/prev")
        end
      end

      context "given collection without an id" do
        let(json) { super.gsub(%q|"id":"prev link",|, %q|"id":"https://test.test/prev",|).gsub(%q|"@id":"https://test.test/foo_bar",|, "") }

        it "does not populate prev" do
          expect(activity.has_key?("prev")).to be_false
        end
      end

      context "given prev with a different host" do
        let(json) { super.gsub(%q|"id":"prev link",|, %q|"id":"https://different/prev",|) }

        it "does not populate prev" do
          expect(activity.has_key?("prev")).to be_false
        end
      end

      context "given prev without an id" do
        let(json) { super.gsub(%q|"id":"prev link",|, "") }

        it "populates prev" do
          expect(activity["prev"]).to be_a(ActivityPub::Collection)
        end
      end
    end

    context "next tests" do
      it "populates next_iri" do
        expect(activity["next_iri"]).to eq("next link")
      end

      it "does not populate next" do
        expect(activity.has_key?("next")).to be_false
      end

      context "given next with the same host" do
        let(json) { super.gsub(%q|"id":"next link",|, %q|"id":"https://test.test/next",|) }

        it "populates next" do
          expect(activity["next"]).to be_a(ActivityPub::Collection)
          expect(activity["next"].as(ActivityPub::Collection).iri).to eq("https://test.test/next")
        end
      end

      context "given collection without an id" do
        let(json) { super.gsub(%q|"id":"next link",|, %q|"id":"https://test.test/next",|).gsub(%q|"@id":"https://test.test/foo_bar",|, "") }

        it "does not populate next" do
          expect(activity.has_key?("next")).to be_false
        end
      end

      context "given next with a different host" do
        let(json) { super.gsub(%q|"id":"next link",|, %q|"id":"https://different/next",|) }

        it "does not populate next" do
          expect(activity.has_key?("next")).to be_false
        end
      end

      context "given next without an id" do
        let(json) { super.gsub(%q|"id":"next link",|, "") }

        it "populates next" do
          expect(activity["next"]).to be_a(ActivityPub::Collection)
        end
      end
    end

    context "current tests" do
      it "populates current_iri" do
        expect(activity["current_iri"]).to eq("current link")
      end

      it "does not populate current" do
        expect(activity.has_key?("current")).to be_false
      end

      context "given current with the same host" do
        let(json) { super.gsub(%q|"id":"current link",|, %q|"id":"https://test.test/current",|) }

        it "populates current" do
          expect(activity["current"]).to be_a(ActivityPub::Collection)
          expect(activity["current"].as(ActivityPub::Collection).iri).to eq("https://test.test/current")
        end
      end

      context "given collection without an id" do
        let(json) { super.gsub(%q|"id":"current link",|, %q|"id":"https://test.test/current",|).gsub(%q|"@id":"https://test.test/foo_bar",|, "") }

        it "does not populate current" do
          expect(activity.has_key?("current")).to be_false
        end
      end

      context "given current with a different host" do
        let(json) { super.gsub(%q|"id":"current link",|, %q|"id":"https://different/current",|) }

        it "does not populate current" do
          expect(activity.has_key?("current")).to be_false
        end
      end

      context "given current without an id" do
        let(json) { super.gsub(%q|"id":"current link",|, "") }

        it "populates current" do
          expect(activity["current"]).to be_a(ActivityPub::Collection)
        end
      end
    end

    context "items tests" do
      let(json) do
        <<-JSON
          {
            "@context":[
              "https://www.w3.org/ns/activitystreams"
            ],
            "@id":"https://test.test/collection",
            "items":[
              "string item id",
              {
                "@id":"https://different.host/object",
                "@type":"Object"
              },
              {
                "@id":"https://test.test/object",
                "@type":"Object"
              }
            ]
          }
        JSON
      end

      let(object) { ActivityPub::Object.new(iri: "https://test.test/object") }

      it "populates items_iris" do
        expect(activity["items_iris"]).to eq(["string item id", "https://different.host/object", "https://test.test/object"])
      end

      it "populates items" do
        expect(activity["items"]).to eq(["string item id", "https://different.host/object", object])
      end

      context "given collection without an id" do
        let(json) { super.gsub(%q|"@id":"https://test.test/collection",|, "") }

        it "populates items_iris" do
          expect(activity["items_iris"]).to eq(["string item id", "https://different.host/object", "https://test.test/object"])
        end

        it "populates items" do
          expect(activity["items"]).to eq(["string item id", "https://different.host/object", "https://test.test/object"])
        end
      end
    end
  end
end
