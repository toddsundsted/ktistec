require "../../src/framework/open"

require "../spec_helper/base"
require "../spec_helper/network"
require "../spec_helper/key_pair"

Spectator.describe Ktistec::Open do
  setup_spec

  let(key_pair) do
    KeyPair.new("https://key_pair")
  end

  describe ".open" do
    it "fetches the page" do
      expect(described_class.open(key_pair, "https://external/specified-page").body).to eq("content")
    end

    it "follows redirects to page" do
      expect(described_class.open(key_pair, "https://external/redirected-page-absolute").body).to eq("content")
    end

    it "follows redirects to page" do
      expect(described_class.open(key_pair, "https://external/redirected-page-relative").body).to eq("content")
    end

    it "fails on errors" do
      expect { described_class.open(key_pair, "https://external/redirected-no-location") }.to raise_error(Ktistec::Open::Error, /Could not redirect/)
    end

    it "fails on errors" do
      expect { described_class.open(key_pair, "https://external/returns-401") }.to raise_error(Ktistec::Open::Error, /Access denied/)
    end

    it "fails on errors" do
      expect { described_class.open(key_pair, "https://external/returns-403") }.to raise_error(Ktistec::Open::Error, /Access denied/)
    end

    it "fails on errors" do
      expect { described_class.open(key_pair, "https://external/returns-404") }.to raise_error(Ktistec::Open::Error, /Does not exist/)
    end

    it "fails on errors" do
      expect { described_class.open(key_pair, "https://external/returns-410") }.to raise_error(Ktistec::Open::Error, /Does not exist/)
    end

    it "fails on errors" do
      expect { described_class.open(key_pair, "https://external/returns-500") }.to raise_error(Ktistec::Open::Error, /Server error/)
    end

    it "fails on errors" do
      expect { described_class.open(key_pair, "https://external:abacab/") }.to raise_error(Ktistec::Open::Error, /Invalid URI/)
    end

    it "fails on errors" do
      expect { described_class.open(key_pair, "https://external/socket-addrinfo-error") }.to raise_error(Ktistec::Open::Error, /Hostname lookup failure/)
    end

    it "fails on errors" do
      expect { described_class.open(key_pair, "https://external/socket-connect-error") }.to raise_error(Ktistec::Open::Error, /Connection failure/)
    end

    it "fails on errors" do
      expect { described_class.open(key_pair, "https://external/openssl-error") }.to raise_error(Ktistec::Open::Error, /Secure connection failure/)
    end

    it "fails on errors" do
      expect { described_class.open(key_pair, "https://external/io-error") }.to raise_error(Ktistec::Open::Error, /I\/O error/)
    end

    context "given a remote object" do
      class MockObject
        property iri : String

        def initialize(@iri)
        end

        def to_json_ld(recursive)
          %Q|{"@id":"#{iri}"}|
        end
      end

      let(mock1) { MockObject.new("https://remote/foo/bar/baz") }
      let(mock2) { MockObject.new("https://remote/?query") }

      before_each do
        HTTP::Client.objects << mock1
        HTTP::Client.objects << mock2
      end

      it "fetches the object" do
        described_class.open(key_pair, mock1.iri)
        expect(HTTP::Client.requests).to have("GET #{mock1.iri}")
      end

      it "fetches the object" do
        described_class.open(key_pair, mock2.iri)
        expect(HTTP::Client.requests).to have("GET #{mock2.iri}")
      end
    end
  end

  describe ".open?" do
    it "returns nil on errors" do
      expect { described_class.open?(key_pair, "https://external/returns-500") }.to be_nil
    end
  end
end
