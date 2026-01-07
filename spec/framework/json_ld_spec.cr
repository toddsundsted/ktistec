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

  context "given JSON document with vocabulary" do
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
        expect(json["https://www.w3.org/ns/activitystreams#name"]).to eq({"und" => "Foo Bar Baz", "fr" => "Foo Bàr Bàz"})
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
      it "returns value as a map" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://www.w3.org/ns/activitystreams#name"]).in_any_order
        expect(json["https://www.w3.org/ns/activitystreams#name"]).to eq({"und" => "Foo Bar Baz"})
      end
    end
  end

  context "given JSON-LD document with uncached context" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "@context": "https://uncached",
            "@type": "Lock",
            "name": "Foo Bar Baz",
            "page": "https://test/"
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "gently ignores the context" do
        expect(json.as_h.keys).to match_array(["@context", "@type"]).in_any_order
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
    let(json) { JSON.parse(%<{"foo":5}>) }

    it "returns the value cast to the specified type" do
      expect(described_class.dig?(json, "foo", as: Int64)).to eq(5)
    end

    it "returns nil if key does not exist" do
      expect(described_class.dig?(json, "bar", as: Int64)).to be_nil
    end
  end

  def block(value)
    if (bar = described_class.dig?(value, "bar", as: Int64)) && (baz = described_class.dig?(value, "baz", as: Int64))
      bar + baz
    end
  end

  describe ".dig_value?" do
    context "given a nested object" do
      let(json) { JSON.parse(%<{"foo":{"bar":3,"baz":5}}>) }

      it "returns the result of the block" do
        result = described_class.dig_value?(json, "foo", &->block(JSON::Any))
        expect(result).to eq(8)
      end
    end

    context "given an array of nested objects" do
      let(json) { JSON.parse(%<{"foo":[{"bar":3,"baz":5},{"bar":1,"baz":2}]}>) }

      it "returns the result of the block on the first element" do
        result = described_class.dig_value?(json, "foo", &->block(JSON::Any))
        expect(result).to eq(8)
      end
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

  describe ".dig_id?" do
    context "given a nested object" do
      let(json) { JSON.parse(%<{"foo":{"@id":"https://test.test/bar"}}>) }

      it "returns the identifier" do
        expect(described_class.dig_id?(json, "foo")).to eq("https://test.test/bar")
      end
    end

    context "given a link" do
      let(json) { JSON.parse(%<{"foo":{"@type":"https://www.w3.org/ns/activitystreams#Link","https://www.w3.org/ns/activitystreams#href":"https://test.test/bar"}}>) }

      it "returns the identifier" do
        expect(described_class.dig_id?(json, "foo")).to eq("https://test.test/bar")
      end
    end

    context "given an identifier" do
      let(json) { JSON.parse(%<{"foo":"https://test.test/bar"}>) }

      it "returns the identifier" do
        expect(described_class.dig_id?(json, "foo")).to eq("https://test.test/bar")
      end
    end

    context "given an array of nested objects" do
      let(json) { JSON.parse(%<{"foo":[{"@id":"https://test.test/bar"}]}>) }

      it "returns the first identifier" do
        expect(described_class.dig_id?(json, "foo")).to eq("https://test.test/bar")
      end
    end

    context "given an array of links" do
      let(json) { JSON.parse(%<{"foo":[{"@type":"https://www.w3.org/ns/activitystreams#Link","https://www.w3.org/ns/activitystreams#href":"https://test.test/bar"}]}>) }

      it "returns the first identifier" do
        expect(described_class.dig_id?(json, "foo")).to eq("https://test.test/bar")
      end
    end

    context "given an array of identifiers" do
      let(json) { JSON.parse(%<{"foo":["https://test.test/bar"]}>) }

      it "returns the first identifier" do
        expect(described_class.dig_id?(json, "foo")).to eq("https://test.test/bar")
      end
    end
  end

  describe ".dig_ids?" do
    context "given a nested object" do
      let(json) { JSON.parse(%<{"foo":{"@id":"https://test.test/bar"}}>) }

      it "returns the identifier as an array" do
        expect(described_class.dig_ids?(json, "foo")).to eq(["https://test.test/bar"])
      end
    end

    context "given a link" do
      let(json) { JSON.parse(%<{"foo":{"@type":"https://www.w3.org/ns/activitystreams#Link","https://www.w3.org/ns/activitystreams#href":"https://test.test/bar"}}>) }

      it "returns the identifier as an array" do
        expect(described_class.dig_ids?(json, "foo")).to eq(["https://test.test/bar"])
      end
    end

    context "given an identifier" do
      let(json) { JSON.parse(%<{"foo":"https://test.test/bar"}>) }

      it "returns the identifier as an array" do
        expect(described_class.dig_ids?(json, "foo")).to eq(["https://test.test/bar"])
      end
    end

    context "given an array of nested objects" do
      let(json) { JSON.parse(%<{"foo":[{"@id":"https://test.test/bar"}]}>) }

      it "returns all the identifiers" do
        expect(described_class.dig_ids?(json, "foo")).to eq(["https://test.test/bar"])
      end
    end

    context "given an array of links" do
      let(json) { JSON.parse(%<{"foo":[{"@type":"https://www.w3.org/ns/activitystreams#Link","https://www.w3.org/ns/activitystreams#href":"https://test.test/bar"}]}>) }

      it "returns all the identifiers" do
        expect(described_class.dig_ids?(json, "foo")).to eq(["https://test.test/bar"])
      end
    end

    context "given an array of identifiers" do
      let(json) { JSON.parse(%<{"foo":["https://test.test/bar"]}>) }

      it "returns all the identifiers" do
        expect(described_class.dig_ids?(json, "foo")).to eq(["https://test.test/bar"])
      end
    end
  end
end
