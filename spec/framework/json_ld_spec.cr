require "../spec_helper"

Spectator.describe Balloon::JSON_LD do
  describe "::CONTEXTS" do
    it "loads stored contexts" do
      expect(Balloon::JSON_LD::CONTEXTS).not_to be_empty
    end
  end

  describe ".expand" do
    let(json) { JSON.parse(%({"name":"Foo Bar"})) }

    it "returns a JSON document" do
      expect(described_class.expand(json)).to be_a(JSON::Any)
    end
  end

  context "given plain JSON document" do
    let(json) do
      described_class.expand(JSON.parse(<<-JSON
          {
            "name": "Foo Bar Baz",
            "page": "https://test/"
          }
        JSON
      ))
    end

    describe "#[]" do
      it "finds no terms" do
        expect(json.as_h.keys).to be_empty
      end
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
              "@context": {
                "Lock": "https://lock",
                "name": "https://name",
                "page": {
                  "@id": "https://page",
                  "@type": "@id"
                }
              }
            }
          JSON
        )
      else
        raise "not found"
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
end
