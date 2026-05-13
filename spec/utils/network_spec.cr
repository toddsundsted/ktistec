require "../../src/utils/network"

require "../spec_helper/base"
require "../spec_helper/network"
require "../spec_helper/key_pair"

Spectator.describe Ktistec::Network do
  setup_spec

  describe ".resolve" do
    it "returns the IRI" do
      expect(described_class.resolve("https://foo.bar/actors/baz")).to eq("https://foo.bar/actors/baz")
    end

    it "resolves and returns the IRI" do
      expect(described_class.resolve("baz@foo.bar")).to eq("https://foo.bar/actors/baz")
    end

    it "resolves and returns the IRI" do
      expect(described_class.resolve("@baz@foo.bar")).to eq("https://foo.bar/actors/baz")
    end

    it "resolves a profile-style URL" do
      expect(described_class.resolve("https://foo.bar/@baz")).to eq("https://foo.bar/actors/baz")
    end

    it "tolerates a trailing slash on a profile-style URL" do
      expect(described_class.resolve("https://foo.bar/@baz/")).to eq("https://foo.bar/actors/baz")
    end

    it "leaves a profile-style URL with a path unchanged" do
      expect(described_class.resolve("https://foo.bar/@baz/123")).to eq("https://foo.bar/@baz/123")
    end

    it "leaves a profile-style URL with a path unchanged" do
      expect(described_class.resolve("https://foo.bar/quux/@baz")).to eq("https://foo.bar/quux/@baz")
    end
  end

  let(key_pair) do
    KeyPair.new("https://key_pair")
  end

  describe ".get" do
    it "fetches the page" do
      expect(described_class.get(key_pair, "https://external/specified-page").body).to eq("content")
    end

    it "follows redirects to page" do
      expect(described_class.get(key_pair, "https://external/redirected-page-absolute").body).to eq("content")
    end

    it "follows redirects to page" do
      expect(described_class.get(key_pair, "https://external/redirected-page-relative").body).to eq("content")
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://external/redirected-no-location") }.to raise_error(Ktistec::Network::Error, /Could not redirect/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://external/returns-401") }.to raise_error(Ktistec::Network::Error, /Access denied/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://external/returns-403") }.to raise_error(Ktistec::Network::Error, /Access denied/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://external/returns-404") }.to raise_error(Ktistec::Network::Error, /Does not exist/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://external/returns-410") }.to raise_error(Ktistec::Network::Error, /Does not exist/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://external/returns-500") }.to raise_error(Ktistec::Network::Error, /Server error/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://external:abacab/") }.to raise_error(Ktistec::Network::Error, /Invalid URI/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://external/socket-addrinfo-error") }.to raise_error(Ktistec::Network::Error, /Hostname lookup failure/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://external/socket-connect-error") }.to raise_error(Ktistec::Network::Error, /Connection failure/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://external/openssl-error") }.to raise_error(Ktistec::Network::Error, /Secure connection failure/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://external/io-error") }.to raise_error(Ktistec::Network::Error, /I\/O error/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://loopback.example/path") }.to raise_error(Ktistec::Network::Error, /Request to private address denied/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://private-ip.example/path") }.to raise_error(Ktistec::Network::Error, /Request to private address denied/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://link-local.example/path") }.to raise_error(Ktistec::Network::Error, /Request to private address denied/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "https://unspecified.example/path") }.to raise_error(Ktistec::Network::Error, /Request to private address denied/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "ftp://example.com/foo") }.to raise_error(Ktistec::Network::Error, /scheme not supported/)
    end

    it "fails on errors" do
      expect { described_class.get(key_pair, "urn:isbn:12345") }.to raise_error(Ktistec::Network::Error, /URL has no host/)
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
        described_class.get(key_pair, mock1.iri)
        expect(HTTP::Client.requests).to have("GET #{mock1.iri}")
      end

      it "fetches the object" do
        described_class.get(key_pair, mock2.iri)
        expect(HTTP::Client.requests).to have("GET #{mock2.iri}")
      end
    end
  end

  describe ".get?" do
    it "returns nil on errors" do
      expect { described_class.get?(key_pair, "https://external/returns-500") }.to be_nil
    end
  end
end
