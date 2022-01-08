require "spectator"

require "../../src/framework/json_ld"

Spectator.describe Ktistec::JSON_LD do
  describe "::CONTEXTS" do
    it "loads stored contexts" do
      expect(Ktistec::JSON_LD::CONTEXTS).not_to be_empty
    end
  end

  describe ".expand" do
    let(json) { JSON.parse(%({"name":"Foo Bar"})) }

    it "returns a JSON document" do
      expect(described_class.expand(json)).to be_a(JSON::Any)
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
    stub load(url) do
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
                "base": "https://base"
              }
            ],
            "@type": "Lock",
            "base": [{
              "name": "Foo Bar Baz",
              "page": "https://test/"
            }]
          }
        JSON
      ), double(loader))
    end

    describe "#[]" do
      it "returns mapped terms" do
        expect(json.as_h.keys).to match_array(["@context", "@type", "https://base"]).in_any_order
        expect(json["https://base"][0].as_h.keys).to match_array(["https://name", "https://page"]).in_any_order
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
end
