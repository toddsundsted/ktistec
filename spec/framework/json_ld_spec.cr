require "spectator"

require "../../src/framework/json_ld"

Spectator.describe Ktistec::JSON_LD do
  describe "::CONTEXTS" do
    it "loads stored contexts" do
      expect(Ktistec::JSON_LD::CONTEXTS).not_to be_empty
    end
  end

  describe ".expand" do
    it "returns a JSON document" do
      json = %|{"name":"Foo Bar"}|
      expect(described_class.expand(json)).to be_a(JSON::Any)
    end

    it "returns a JSON document" do
      json = IO::Memory.new(%|{"name":"Foo Bar"}|)
      expect(described_class.expand(json)).to be_a(JSON::Any)
    end

    it "returns a JSON document" do
      json = JSON.parse(%|{"name":"Foo Bar"}|)
      expect(described_class.expand(json)).to be_a(JSON::Any)
    end

    it "raises an error" do
      json = "[]"
      expect { described_class.expand(json) }.to raise_error(Ktistec::JSON_LD::Error)
    end
  end

  context "given JSON-LD document with unsupported keywords" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": "https://www.w3.org/ns/activitystreams",
            "@graph": [{"type": "Note"}],
            "@included": [{"type": "Note"}],
            "@reverse": {"https://attributedTo": "https://actor/"},
            "name": "Foo Bar Baz"
          }
        JSON
      ))
    end

    describe "#[]" do
      it "drops unsupported keywords" do
        expect(json.as_h.keys).to contain("@context")
        expect(json.as_h.keys).not_to contain("@graph")
        expect(json.as_h.keys).not_to contain("@included")
        expect(json.as_h.keys).not_to contain("@reverse")
      end

      it "preserves non-keyword content" do
        expect(json.as_h.keys).to contain("https://www.w3.org/ns/activitystreams#name")
      end
    end
  end

  context "given JSON-LD document with a term aliased to an unsupported keyword" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": {
              "graph": "@graph"
            },
            "graph": [{"type": "Note"}],
            "https://name": "Foo Bar Baz"
          }
        JSON
      ))
    end

    describe "#[]" do
      it "drops the aliased keyword" do
        expect(json.as_h.keys).to match_array(["@context", "https://name"]).in_any_order
      end
    end
  end

  context "given JSON-LD document with vocabulary" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@type": "https://lock",
            "https://name": "Foo Bar Baz",
            "https://page": "https://test/"
          }
        JSON
      ))
    end

    describe "#[]" do
      it "returns terms" do
        expect(json.as_h.keys).to match_array(["@type", "https://name", "https://page"]).in_any_order
        expect(json["@type"]).to eq("https://lock")
      end
    end
  end

  double loader do
    stub def load(url)
      case url
      when "https://vocab"
        JSON.parse(<<-JSON
            {
              "Lock": "https://lock",
              "name": "https://name",
              "page": {
                "@id": "https://page",
                "@type": "@id"
              }
            }
          JSON
        )
      else
        Ktistec::JSON_LD::Loader.new.load(url)
      end
    end
  end

  context "given JSON-LD document with embedded context" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": {
              "Lock": "https://lock",
              "name": "https://name",
              "page": {
                "@id": "https://page",
                "@type": "@id"
              }
            },
            "@type": "Lock",
            "name": "Foo Bar Baz",
            "page": "https://test/"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "returns mapped terms" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://name", "https://page"]).in_any_order
        expect(json["@type"]).to eq("https://lock")
      end
    end
  end

  context "given JSON-LD document with remote context" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": "https://vocab",
            "@type": "Lock",
            "name": "Foo Bar Baz",
            "page": "https://test/"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "returns mapped terms" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://name", "https://page"]).in_any_order
        expect(json["@type"]).to eq("https://lock")
      end
    end
  end

  context "given JSON-LD document with mixed context" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": [
              "https://vocab",
              {
                "full": "https://full"
              }
            ],
            "@type": "Lock",
            "full": "Foo Bar Baz",
            "page": "https://test/"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "returns mapped terms" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://full", "https://page"]).in_any_order
        expect(json["@type"]).to eq("https://lock")
      end
    end
  end

  context "given JSON-LD document using compact IRIs" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": {
              "xx": "https://"
            },
            "@type": "xx:lock",
            "xx:name": "Foo Bar Baz",
            "xx:page": "https://test/"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "returns mapped terms" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://name", "https://page"]).in_any_order
        expect(json["@type"]).to eq("https://lock")
      end
    end
  end

  context "given JSON-LD document using compact IRIs" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": {
              "xx": "https://",
              "Lock": "xx:lock",
              "name": "xx:name",
              "page": {
                "@id": "xx:page",
                "@type": "@id"
              }
            },
            "@type": "Lock",
            "name": "Foo Bar Baz",
            "page": "https://test/"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "returns mapped terms" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://name", "https://page"]).in_any_order
        expect(json["@type"]).to eq("https://lock")
      end
    end
  end

  context "given JSON-LD document using compact IRIs" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": [
              {
                "xx": "https://"
              },
              {
                "Lock": "xx:lock",
                "name": "xx:name",
                "page": {
                  "@id": "xx:page",
                  "@type": "@id"
                }
              }
            ],
            "@type": "Lock",
            "name": "Foo Bar Baz",
            "page": "https://test/"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "returns mapped terms" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://name", "https://page"]).in_any_order
        expect(json["@type"]).to eq("https://lock")
      end
    end
  end

  context "given JSON-LD document with mapped keys" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": [
              {
                "id": "@id",
                "type": "@type"
              },
              {
                "Lock": {
                  "id": "https://lock",
                  "type": "@id"
                }
              }
            ],
            "id": "https://id",
            "type": "Lock"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "returns mapped terms" do
        expect(json.as_h.keys).to match_array(["@context", "@id", "@type"]).in_any_order
        expect(json["@id"]).to eq("https://id")
        expect(json["@type"]).to eq("https://lock")
      end
    end
  end

  context "given JSON-LD document with nested objects" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": [
              "https://vocab",
              {
                "node": "https://root"
              }
            ],
            "name": "Root",
            "node": [{
              "@context": {
                "node": "https://node"
              },
              "name": "Node",
              "node": [{
                "@context": {
                  "node": "https://leaf"
                },
                "name": "Leaf",
                "node": [
                ]
              }]
            }]
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "returns mapped terms" do
        expect(json.as_h.keys).to match_array(["@context", "https://name", "https://root"]).in_any_order
        expect(json["https://root"][0].as_h.keys).to match_array(["@context", "https://name", "https://node"]).in_any_order
        expect(json["https://root"][0]["https://node"][0].as_h.keys).to match_array(["@context", "https://name", "https://leaf"]).in_any_order
      end
    end
  end

  context "given JSON-LD document with natural language values" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": {
              "ns": "https://www.w3.org/ns/activitystreams#",
              "name": "ns:name",
              "nameMap": {
                "@id": "ns:name"
              }
            },
            "@type": "https://lock",
            "name": "Foo Bar Baz",
            "nameMap": {
              "fr": "Foo Bàr Bàz"
            }
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "returns merged values" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://www.w3.org/ns/activitystreams#name"]).in_any_order
        expect(json["https://www.w3.org/ns/activitystreams#name"]).to eq([{"und" => "Foo Bar Baz", "fr" => "Foo Bàr Bàz"}])
      end
    end
  end

  context "given JSON-LD document with no natural language values" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": {
              "ns": "https://www.w3.org/ns/activitystreams#",
              "name": "ns:name",
              "nameMap": {
                "@id": "ns:name"
              }
            },
            "@type": "https://lock",
            "name": "Foo Bar Baz"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "returns value as a set containing a map" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://www.w3.org/ns/activitystreams#name"]).in_any_order
        expect(json["https://www.w3.org/ns/activitystreams#name"]).to eq([{"und" => "Foo Bar Baz"}])
      end
    end
  end

  context "given JSON-LD document with a value object" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": "https://www.w3.org/ns/activitystreams",
            "@type": "https://lock",
            "mediaType": {"@value": "Note", "@language": "Person"}
          }
        JSON
      ))
    end

    describe "#[]" do
      it "does not IRI-expand the @value or @language literals" do
        expect(json["https://www.w3.org/ns/activitystreams#mediaType"]).to eq([{"@value" => "Note", "@language" => "Person"}])
      end
    end
  end

  context "given JSON-LD document with id-valued properties" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": "https://www.w3.org/ns/activitystreams",
            "to": ["as:Public", "https://www.w3.org/ns/activitystreams#Public"],
            "cc": ["Public", "https://www.w3.org/ns/activitystreams#Public"]
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "expands id-valued properties" do
        to_values = json["https://www.w3.org/ns/activitystreams#to"].as_a.map(&.as_s)
        cc_values = json["https://www.w3.org/ns/activitystreams#cc"].as_a.map(&.as_s)
        expect(to_values).to eq(["https://www.w3.org/ns/activitystreams#Public", "https://www.w3.org/ns/activitystreams#Public"])
        expect(cc_values).to eq(["https://www.w3.org/ns/activitystreams#Public", "https://www.w3.org/ns/activitystreams#Public"])
      end
    end
  end

  context "given JSON-LD document normalized to sets" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": "https://www.w3.org/ns/activitystreams",
            "@type": "Note",
            "published": "2016-02-15T10:20:30Z",
            "to": ["https://a/", "https://b/"]
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "wraps a scalar property value in a set" do
        expect(json["https://www.w3.org/ns/activitystreams#published"].as_a?.try(&.map(&.as_s))).to eq(["2016-02-15T10:20:30Z"])
      end

      it "leaves a keyword value scalar" do
        expect(json["@type"].as_a?).to be_nil
      end

      it "does not double-wrap an array property value" do
        expect(json["https://www.w3.org/ns/activitystreams#to"].as_a.size).to eq(2)
      end
    end
  end

  context "given JSON-LD document with uncached context" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": "https://uncached",
            "@type": "Lock",
            "name": "Foo Bar Baz"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "falls back to activitystreams context" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://www.w3.org/ns/activitystreams#name"]).in_any_order
      end
    end
  end

  context "given JSON-LD document with array of uncached context" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": ["https://uncached"],
            "@type": "Lock",
            "name": "Foo Bar Baz"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "falls back to activitystreams context" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://www.w3.org/ns/activitystreams#name"]).in_any_order
      end
    end
  end

  context "given JSON-LD document with empty context array" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": [],
            "@type": "Lock",
            "name": "Foo Bar Baz"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "falls back to activitystreams context" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://www.w3.org/ns/activitystreams#name"]).in_any_order
      end
    end
  end

  context "given a context term without an id" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": [
              {
                "page": {
                  "@type": "@id"
                }
              }
            ]
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "ignores the invalid term" do
        expect(json.as_h.keys).to match_array(["@context"]).in_any_order
      end
    end
  end

  context "given no context" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "type": "Object",
            "id": "https://object/"
          }
        JSON
      ))
    end

    describe "#[]" do
      it "assumes an activitystreams context applies" do
        expect(json.as_h.keys).to match_array(["@type", "@id"]).in_any_order
      end
    end
  end

  context "given a URL to a locally hosted litepub schema" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": "https://foo.bar.baz/litepub-0.1.jsonld",
            "type": "Object",
            "id": "https://object/"
          }
        JSON
      ))
    end

    describe "#[]" do
      it "assumes a canonical litepub context applies" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "@id"]).in_any_order
      end
    end
  end

  describe ".dig?" do
    context "given a scalar-valued (compacted) property" do
      it "returns the value cast to the specified type" do
        json = JSON.parse(%<{"foo":5}>)
        expect(described_class.dig?(json, "foo", as: Int64)).to eq(5)
      end

      it "returns the value cast to the specified type" do
        json = JSON.parse(%<{"foo":5}>)
        expect(described_class.dig?(json, "foo", as: Int32)).to eq(5)
      end

      it "returns nil if key does not exist" do
        json = JSON.parse(%<{"foo":5}>)
        expect(described_class.dig?(json, "bar", as: Int64)).to be_nil
      end
    end

    context "given a set-valued (expanded) property" do
      it "collapses a singleton set to its member" do
        json = JSON.parse(%<{"foo":["bar"]}>)
        expect(described_class.dig?(json, "foo")).to eq("bar")
      end

      it "takes the first member of a multi-valued set" do
        json = JSON.parse(%<{"foo":["bar","baz"]}>)
        expect(described_class.dig?(json, "foo")).to eq("bar")
      end

      it "returns nil for an empty set" do
        json = JSON.parse(%<{"foo":[]}>)
        expect(described_class.dig?(json, "foo")).to be_nil
      end

      it "collapses sets at each level of a multi-level selector" do
        json = JSON.parse(%<{"foo":[{"bar":["baz"]}]}>)
        expect(described_class.dig?(json, "foo", "bar")).to eq("baz")
      end

      it "takes the first member of a multi-valued set mid-selector" do
        json = JSON.parse(%<{"foo":[{"bar":"a"},{"bar":"b"}]}>)
        expect(described_class.dig?(json, "foo", "bar")).to eq("a")
      end

      it "returns nil for an empty set mid-selector" do
        json = JSON.parse(%<{"foo":[]}>)
        expect(described_class.dig?(json, "foo", "bar")).to be_nil
      end

      it "casts the collapsed member to the specified type" do
        json = JSON.parse(%<{"foo":[true]}>)
        expect(described_class.dig?(json, "foo", as: Bool)).to be_true
      end
    end
  end

  describe ".dig_first?" do
    context "given a scalar-valued (compacted) property" do
      it "returns the value" do
        json = JSON.parse(%<{"foo":"bar"}>)
        expect(described_class.dig_first?(json, "foo")).to eq("bar")
      end

      it "returns nil if key does not exist" do
        json = JSON.parse(%<{"foo":"bar"}>)
        expect(described_class.dig_first?(json, "baz")).to be_nil
      end
    end

    context "given a set-valued (expanded) property" do
      it "returns the first member" do
        json = JSON.parse(%<{"foo":["bar","baz"]}>)
        expect(described_class.dig_first?(json, "foo")).to eq("bar")
      end

      it "returns an object member for the caller to inspect" do
        json = JSON.parse(%<{"foo":[{"@id":"https://x/"}]}>)
        expect(described_class.dig_first?(json, "foo").try(&.dig?("@id"))).to eq("https://x/")
      end

      it "returns nil for an empty set" do
        json = JSON.parse(%<{"foo":[]}>)
        expect(described_class.dig_first?(json, "foo")).to be_nil
      end

      it "collapses sets at each level" do
        json = JSON.parse(%<{"foo":[{"bar":[{"@id":"https://x/"}]}]}>)
        expect(described_class.dig_first?(json, "foo", "bar").try(&.dig?("@id"))).to eq("https://x/")
      end
    end
  end

  def block(value)
    if (bar = described_class.dig?(value, "bar", as: Int64)) && (baz = described_class.dig?(value, "baz", as: Int64))
      bar + baz
    end
  end

  describe ".dig_values?" do
    context "given a nested object" do
      let(json) { JSON.parse(%<{"foo":{"bar":3,"baz":5}}>) }

      it "returns the result of the block as an array" do
        result = described_class.dig_values?(json, "foo", &->block(JSON::Any))
        expect(result).to eq([8])
      end
    end

    context "given an array of nested objects" do
      let(json) { JSON.parse(%<{"foo":[{"bar":3,"baz":5},{"bar":1,"baz":2}]}>) }

      it "returns the result of the block on all elements" do
        result = described_class.dig_values?(json, "foo", &->block(JSON::Any))
        expect(result).to eq([8, 3])
      end
    end
  end

  def expand_as(body)
    described_class.expand(JSON.parse(%<{"@context":"https://www.w3.org/ns/activitystreams",#{body}}>))
  end

  describe ".dig_id?" do
    context "given a value with an @id" do
      let(json) { expand_as(%<"attributedTo":{"id":"https://test.test/bar"}>) }

      it "returns its identifier" do
        expect(described_class.dig_id?(json, "https://www.w3.org/ns/activitystreams#attributedTo")).to eq("https://test.test/bar")
      end
    end

    context "given a Link value" do
      let(json) { expand_as(%<"url":{"type":"Link","href":"https://test.test/bar"}>) }

      it "returns its identifier" do
        expect(described_class.dig_id?(json, "https://www.w3.org/ns/activitystreams#url")).to eq("https://test.test/bar")
      end
    end

    context "given a bare IRI value" do
      let(json) { expand_as(%<"to":"https://test.test/bar">) }

      it "returns its identifier" do
        expect(described_class.dig_id?(json, "https://www.w3.org/ns/activitystreams#to")).to eq("https://test.test/bar")
      end
    end

    context "given multiple values" do
      let(json) { expand_as(%<"to":["https://test.test/a","https://test.test/b"]>) }

      it "returns the first identifier" do
        expect(described_class.dig_id?(json, "https://www.w3.org/ns/activitystreams#to")).to eq("https://test.test/a")
      end
    end

    context "given a value via a nested selector" do
      let(json) { expand_as(%<"endpoints":{"sharedInbox":"https://test.test/shared"}>) }

      it "returns its identifier" do
        expect(described_class.dig_id?(json, "https://www.w3.org/ns/activitystreams#endpoints", "https://www.w3.org/ns/activitystreams#sharedInbox")).to eq("https://test.test/shared")
      end
    end

    context "given no values" do
      let(json) { expand_as(%<"to":[]>) }

      it "returns nil" do
        expect(described_class.dig_id?(json, "https://www.w3.org/ns/activitystreams#to")).to be_nil
      end
    end
  end

  describe ".dig_ids?" do
    context "given a value with an @id" do
      let(json) { expand_as(%<"attributedTo":{"id":"https://test.test/bar"}>) }

      it "returns its identifier as an array" do
        expect(described_class.dig_ids?(json, "https://www.w3.org/ns/activitystreams#attributedTo")).to eq(["https://test.test/bar"])
      end
    end

    context "given a Link value" do
      let(json) { expand_as(%<"url":{"type":"Link","href":"https://test.test/bar"}>) }

      it "returns its identifier as an array" do
        expect(described_class.dig_ids?(json, "https://www.w3.org/ns/activitystreams#url")).to eq(["https://test.test/bar"])
      end
    end

    context "given multiple values" do
      let(json) { expand_as(%<"to":["https://test.test/a","https://test.test/b"]>) }

      it "returns all the identifiers" do
        expect(described_class.dig_ids?(json, "https://www.w3.org/ns/activitystreams#to")).to eq(["https://test.test/a", "https://test.test/b"])
      end
    end

    context "given no values" do
      let(json) { expand_as(%<"to":[]>) }

      it "returns an empty array" do
        expect(described_class.dig_ids?(json, "https://www.w3.org/ns/activitystreams#to")).to be_empty
      end
    end
  end
end
