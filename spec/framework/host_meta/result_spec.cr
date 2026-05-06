require "spectator"

require "../../../src/framework/host_meta"
require "../../../src/ktistec/constants"

Spectator.describe Ktistec::HostMeta::Result do
  describe ".from_xml" do
    it "parses an application/xrd+xml result" do
      expect(Ktistec::HostMeta::Result.from_xml("<XRD/>")).to be_a(Ktistec::HostMeta::Result)
    end

    it "maps properties" do
      result = Ktistec::Constants::XRD_ENV % "<Property type='one'>1</Property><Property type='two' xsi:nil='true'/>"
      expect(Ktistec::HostMeta::Result.from_xml(result).properties).to eq({"one" => "1", "two" => nil})
    end

    context "links" do
      it "parses links" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='one' href='1'/>"
        expect(Ktistec::HostMeta::Result.from_xml(result).links).to be_a(Array(Ktistec::HostMeta::Result::Link))
      end

      it "maps rel" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='self'/>"
        links = Ktistec::HostMeta::Result.from_xml(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.rel)).to eq("self")
      end

      it "maps type" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='self' type='text'/>"
        links = Ktistec::HostMeta::Result.from_xml(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.type)).to eq("text")
      end

      it "maps template" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='self' template='https://example.com/?uri={uri}'/>"
        links = Ktistec::HostMeta::Result.from_xml(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.template)).to eq("https://example.com/?uri={uri}")
      end

      it "maps href" do
        result = Ktistec::Constants::XRD_ENV % "<Link rel='self' href='urn:xyz'/>"
        links = Ktistec::HostMeta::Result.from_xml(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.href)).to eq("urn:xyz")
      end
    end
  end

  describe ".from_json" do
    it "parses an application/jrd+json result" do
      expect(Ktistec::HostMeta::Result.from_json("{}")).to be_a(Ktistec::HostMeta::Result)
    end

    it "maps properties" do
      result = %[{"properties":{"one":"1","two":null}}]
      expect(Ktistec::HostMeta::Result.from_json(result).properties).to eq({"one" => "1", "two" => nil})
    end

    context "links" do
      it "parses links" do
        result = %[{"links":[]}]
        expect(Ktistec::HostMeta::Result.from_json(result).links).to be_a(Array(Ktistec::HostMeta::Result::Link))
      end

      it "maps rel" do
        result = %[{"links":[{"rel":"self"}]}]
        links = Ktistec::HostMeta::Result.from_json(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.rel)).to eq("self")
      end

      it "maps type" do
        result = %[{"links":[{"rel":"self","type":"text"}]}]
        links = Ktistec::HostMeta::Result.from_json(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.type)).to eq("text")
      end

      it "maps template" do
        result = %[{"links":[{"rel":"self","template":"https://example.com/?uri={uri}"}]}]
        links = Ktistec::HostMeta::Result.from_json(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.template)).to eq("https://example.com/?uri={uri}")
      end

      it "maps href" do
        result = %[{"links":[{"rel":"self","href":"urn:xyz"}]}]
        links = Ktistec::HostMeta::Result.from_json(result).links
        expect(links.try(&.size)).to eq(1)
        expect(links.try(&.first.href)).to eq("urn:xyz")
      end
    end
  end

  describe "#property" do
    it "returns the value of the property" do
      result = Ktistec::Constants::XRD_ENV % "<Property type='one'>1</Property><Property type='two' xsi:nil='true'/>"
      expect(Ktistec::HostMeta::Result.from_xml(result).property("one")).to eq("1")
    end
  end

  describe "#property?" do
    it "returns true if the property has a value" do
      result = Ktistec::Constants::XRD_ENV % "<Property type='one'>1</Property><Property type='two' xsi:nil='true'/>"
      expect(Ktistec::HostMeta::Result.from_xml(result).property?("one")).to be_true
    end
  end

  describe "#links" do
    it "returns the links with the specified rel" do
      result = Ktistec::Constants::XRD_ENV % "<Link rel='next' href='next/1'/><Link rel='prev' href='prev/1'/>"
      expect(Ktistec::HostMeta::Result.from_xml(result).links("next").map(&.href)).to eq(["next/1"])
    end
  end

  describe "#links?" do
    it "returns true if the specified rel has any values" do
      result = Ktistec::Constants::XRD_ENV % "<Link rel='next' href='next/1'/><Link rel='prev' href='prev/1'/>"
      expect(Ktistec::HostMeta::Result.from_xml(result).links?("next")).to be_true
    end
  end
end
