require "spectator"

require "../../../src/framework/web_finger"
require "../../../src/ktistec/constants"

Spectator.describe Ktistec::WebFinger::Result do
  describe ".from_xml" do
    it "parses an application/xrd+xml result" do
      expect(Ktistec::WebFinger::Result.from_xml("<XRD/>")).to be_a(Ktistec::WebFinger::Result)
    end

    it "maps the subject" do
      result = Ktistec::Constants::XRD_ENV % "<Subject>acct:subject</Subject>"
      expect(Ktistec::WebFinger::Result.from_xml(result).subject).to eq("acct:subject")
    end

    it "maps aliases" do
      result = Ktistec::Constants::XRD_ENV % "<Alias>one</Alias><Alias>two</Alias>"
      expect(Ktistec::WebFinger::Result.from_xml(result).aliases).to eq(["one", "two"])
    end

    it "maps properties" do
      result = Ktistec::Constants::XRD_ENV % "<Property type='one'>1</Property><Property type='two' xsi:nil='true'/>"
      expect(Ktistec::WebFinger::Result.from_xml(result).properties).to eq({"one" => "1", "two" => nil})
    end

    context "links" do
      it "parses links" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='one' href='1'/>"
        expect(Ktistec::WebFinger::Result.from_xml(result).links).to be_a(Hash(String, Ktistec::WebFinger::Result::Link))
      end

      it "maps rel" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='self'/>"
        links = Ktistec::WebFinger::Result.from_xml(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.rel)).to eq("self")
      end

      it "maps type" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='self' type='text'/>"
        links = Ktistec::WebFinger::Result.from_xml(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.type)).to eq("text")
      end

      it "maps href" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='self' href='urn:xyz'/>"
        links = Ktistec::WebFinger::Result.from_xml(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.href)).to eq("urn:xyz")
      end

      it "maps properties" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='self'><Property type='one'>1</Property><Property type='two' xsi:nil='true'/></Link>"
        links = Ktistec::WebFinger::Result.from_xml(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.properties)).to eq({"one" => "1", "two" => nil})
      end

      it "maps titles" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='self'><Title xml:lang='en'>Test</Title><Title>Default</Title></Link>"
        links = Ktistec::WebFinger::Result.from_xml(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.titles)).to eq({"default" => "Default", "en" => "Test"})
      end

      it "maps template" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='self' template='https://example.com/?uri={uri}'/>"
        links = Ktistec::WebFinger::Result.from_xml(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.template)).to eq("https://example.com/?uri={uri}")
      end
    end
  end

  describe ".from_json" do
    it "parses an application/jrd+json result" do
      expect(Ktistec::WebFinger::Result.from_json("{}")).to be_a(Ktistec::WebFinger::Result)
    end

    it "maps the subject" do
      result = %[{"subject":"acct:subject"}]
      expect(Ktistec::WebFinger::Result.from_json(result).subject).to eq("acct:subject")
    end

    it "maps aliases" do
      result = %[{"aliases":["one","two"]}]
      expect(Ktistec::WebFinger::Result.from_json(result).aliases).to eq(["one", "two"])
    end

    it "maps properties" do
      result = %[{"properties":{"one":"1","two":null}}]
      expect(Ktistec::WebFinger::Result.from_json(result).properties).to eq({"one" => "1", "two" => nil})
    end

    context "links" do
      it "parses links" do
        result = %[{"links":[]}]
        expect(Ktistec::WebFinger::Result.from_json(result).links).to be_a(Hash(String, Ktistec::WebFinger::Result::Link))
      end

      it "maps rel" do
        result = %[{"links":[{"rel":"self"}]}]
        links = Ktistec::WebFinger::Result.from_json(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.rel)).to eq("self")
      end

      it "maps type" do
        result = %[{"links":[{"rel":"self","type":"text"}]}]
        links = Ktistec::WebFinger::Result.from_json(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.type)).to eq("text")
      end

      it "maps href" do
        result = %[{"links":[{"rel":"self","href":"urn:xyz"}]}]
        links = Ktistec::WebFinger::Result.from_json(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.href)).to eq("urn:xyz")
      end

      it "maps properties" do
        result = %[{"links":[{"rel":"self","properties":{"one":"1","two":null}}]}]
        links = Ktistec::WebFinger::Result.from_json(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.properties)).to eq({"one" => "1", "two" => nil})
      end

      it "maps titles" do
        result = %[{"links":[{"rel":"self","titles":{"en":"Test"}}]}]
        links = Ktistec::WebFinger::Result.from_json(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.titles)).to eq({"en" => "Test"})
      end

      it "maps template" do
        result = %[{"links":[{"rel":"self","template":"https://example.com/?uri={uri}"}]}]
        links = Ktistec::WebFinger::Result.from_json(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.last.template)).to eq("https://example.com/?uri={uri}")
      end
    end
  end

  describe "#property" do
    it "returns the value of the key" do
      result = %[{"properties":{"one":"1","two":null}}]
      expect(Ktistec::WebFinger::Result.from_json(result).property("one")).to eq("1")
    end
  end

  describe "#property?" do
    it "returns true if the key has a value" do
      result = %[{"properties":{"one":"1","two":null}}]
      expect(Ktistec::WebFinger::Result.from_json(result).property?("one")).to be_true
    end
  end

  describe "#link" do
    it "returns the value of the key" do
      result = %[{"links":[{"rel":"next","href":"next/1"},{"rel":"prev","href":"prev/1"}]}]
      expect(Ktistec::WebFinger::Result.from_json(result).link("next").href).to eq("next/1")
    end
  end

  describe "#link?" do
    it "returns true if the key has a value" do
      result = %[{"links":[{"rel":"next","href":"next/1"},{"rel":"prev","href":"prev/1"}]}]
      expect(Ktistec::WebFinger::Result.from_json(result).link?("next")).to be_true
    end
  end
end
