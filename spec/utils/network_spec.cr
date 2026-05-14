require "../../src/utils/network"

require "../spec_helper/base"
require "../spec_helper/network"
require "../spec_helper/key_pair"

# redefine as public for testing
module Ktistec
  module Network
    def classify(addr : Socket::IPAddress)
      previous_def
    end
  end
end

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
      expect { described_class.get(key_pair, "https://multi-answer-mixed.example/path") }.to raise_error(Ktistec::Network::Error, /Request to private address denied/)
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

  describe ".safe_for_untrusted_outbound_http?" do
    # the "accepts public" blocks check boundaries just outside each
    # registered range.

    it "rejects non-public IPv4 addresses" do
      [
        # 0.0.0.0/32 "This host on this network" + 0.0.0.0/8 "This network"
        "0.0.0.0", "0.1.2.3", "0.255.255.255",
        # 10.0.0.0/8 private-use
        "10.0.0.1",
        # 100.64.0.0/10 shared address space
        "100.64.0.0", "100.64.0.1", "100.127.255.255",
        # 127.0.0.0/8 loopback
        "127.0.0.1", "127.0.0.5",
        # 169.254.0.0/16 link local
        "169.254.0.1", "169.254.255.255",
        # 172.16.0.0/12 private-use
        "172.16.0.1",
        # 192.0.0.0/24 IETF protocol assignments and nested entries
        "192.0.0.0", "192.0.0.7", "192.0.0.8", "192.0.0.9", "192.0.0.10",
        "192.0.0.50", "192.0.0.170", "192.0.0.171", "192.0.0.255",
        # 192.0.2.0/24 documentation (TEST-NET-1)
        "192.0.2.0", "192.0.2.255",
        # 192.31.196.0/24 AS112-v4
        "192.31.196.0", "192.31.196.128", "192.31.196.255",
        # 192.52.193.0/24 AMT
        "192.52.193.0", "192.52.193.255",
        # 192.88.99.0/24 deprecated (6to4 relay anycast) and 192.88.99.2/32 6a44-relay
        "192.88.99.0", "192.88.99.2", "192.88.99.255",
        # 192.168.0.0/16 private-use
        "192.168.1.1",
        # 192.175.48.0/24 direct delegation AS112 service
        "192.175.48.0", "192.175.48.255",
        # 198.18.0.0/15 benchmarking
        "198.18.0.0", "198.18.255.255", "198.19.0.0", "198.19.255.255",
        # 198.51.100.0/24 documentation (TEST-NET-2)
        "198.51.100.0", "198.51.100.255",
        # 203.0.113.0/24 documentation (TEST-NET-3)
        "203.0.113.0", "203.0.113.255",
        # 224.0.0.0/4 multicast
        "224.0.0.0", "239.255.255.255",
        # 240.0.0.0/4 reserved and 255.255.255.255/32 limited broadcast
        "240.0.0.0", "255.255.255.255",
      ].each do |ip_str|
        expect(described_class.safe_for_untrusted_outbound_http?(Socket::IPAddress.new(ip_str, 0))).to be_false, "expected #{ip_str} to be unsafe"
      end
    end

    it "accepts public IPv4 addresses" do
      [
        "1.1.1.1", "8.8.8.8", "93.184.216.34",
        # boundaries just outside each range
        "100.63.255.255", "100.128.0.0",
        "192.0.1.0", "192.0.3.0",
        "192.31.195.255", "192.31.197.0",
        "192.52.192.255", "192.52.194.0",
        "192.88.98.255", "192.88.100.0",
        "192.175.47.255", "192.175.49.0",
        "198.51.99.255", "198.51.101.0",
        "203.0.112.255", "203.0.114.0",
        "198.17.255.255", "198.20.0.0",
        "223.255.255.255",
      ].each do |ip_str|
        expect(described_class.safe_for_untrusted_outbound_http?(Socket::IPAddress.new(ip_str, 0))).to be_true, "expected #{ip_str} to be safe"
      end
    end

    it "rejects non-public IPv6 addresses" do
      [
        # ::/128 unspecified, ::1/128 loopback
        "::", "::1",
        # ::/96 IPv4-compatible IPv6 (deprecated)
        "::127.0.0.1", "::10.0.0.1", "::192.168.0.1", "::8.8.8.8",
        # ::ffff:0:0/96 IPv4-mapped
        "::ffff:10.0.0.1", "::ffff:127.0.0.1", "::ffff:1.2.3.4",
        # 64:ff9b::/96 NAT64 well-known
        "64:ff9b::", "64:ff9b::1.2.3.4", "64:ff9b::10.0.0.1", "64:ff9b::127.0.0.1",
        # 64:ff9b:1::/48 NAT64 local-use
        "64:ff9b:1::", "64:ff9b:1:1::1",
        # 100::/64 discard-only
        "100::", "100::1",
        # 100:0:0:1::/64 dummy IPv6 prefix
        "100:0:0:1::", "100:0:0:1::1",
        # 2001::/23 IETF protocol assignments and nested entries
        "2001::", "2001::1", "2001:1::1", "2001:1::2", "2001:1::3",
        "2001:2::", "2001:3::1", "2001:4:112::", "2001:5::1",
        "2001:10::1", "2001:20::1", "2001:30::1", "2001:1ff::1",
        # 2001:db8::/32 documentation
        "2001:db8::", "2001:db8::1",
        # 2002::/16 6to4
        "2002::", "2002:0a00:0001::1",
        # 2620:4f:8000::/48 direct delegation AS112 service
        "2620:4f:8000::", "2620:4f:8000::1", "2620:4f:8000:ffff:ffff:ffff:ffff:ffff",
        # 3fff::/20 documentation
        "3fff::", "3fff:0fff::1",
        # 5f00::/16 segment routing (SRv6) SIDs
        "5f00::", "5f00:1::1",
        # fc00::/7 unique-local
        "fc00::", "fd00::1",
        # fe80::/10 link-local unicast
        "fe80::", "fe80::1",
        # ff00::/8 multicast
        "ff00::", "ff02::1",
      ].each do |ip_str|
        expect(described_class.safe_for_untrusted_outbound_http?(Socket::IPAddress.new(ip_str, 0))).to be_false, "expected #{ip_str} to be unsafe"
      end
    end

    it "accepts public IPv6 addresses" do
      [
        "2606:4700:4700::1111",
        # just outside 2001:db8::/32
        "2001:db9::1",
        # just outside 2001::/23
        "2001:200::1", "2001:ffff::1",
        # just outside 2620:4f:8000::/48
        "2620:4f:7fff:ffff:ffff:ffff:ffff:ffff", "2620:4f:8001::",
        # just outside 3fff::/20
        "3fff:1000::",
        # just outside 5f00::/16
        "5f01::",
      ].each do |ip_str|
        expect(described_class.safe_for_untrusted_outbound_http?(Socket::IPAddress.new(ip_str, 0))).to be_true, "expected #{ip_str} to be safe"
      end
    end
  end

  describe "the registry classifier" do
    # verify that lookup returns the most-specific matching registry
    # entry. the behavioral specs above cannot distinguish between
    # different reasons for the same boolean outcome.

    it "returns the most-specific IPv4 registry entry containing the address" do
      # 192.0.0.9 is inside both 192.0.0.0/24 and the /32 carve-out.
      # the /32 must win.
      block = described_class.classify(Socket::IPAddress.new("192.0.0.9", 0))
      expect(block.try(&.name)).to eq("Port Control Protocol Anycast")
      expect(block.try(&.prefix_length)).to eq(32)
      expect(block.try(&.rfc)).to eq("RFC 7723")
      expect(block.try(&.globally_reachable)).to be_true
    end

    it "returns the /29 child block inside 192.0.0.0/24" do
      # 192.0.0.5 is inside the /24 IETF protocol assignments and the
      # nested /29 IPv4 service continuity prefix (192.0.0.0–7). the
      # /29 must win.
      block = described_class.classify(Socket::IPAddress.new("192.0.0.5", 0))
      expect(block.try(&.name)).to eq("IPv4 Service Continuity Prefix")
      expect(block.try(&.prefix_length)).to eq(29)
      expect(block.try(&.rfc)).to eq("RFC 7335")
      expect(block.try(&.globally_reachable)).to be_false
    end

    it "returns the /24 parent inside 192.0.0.0/24 but outside any /29 or /32" do
      # 192.0.0.50 is inside the /24 IETF protocol assignments but
      # not inside /29 IPv4 service continuity and not at any /32
      # carve-out.
      block = described_class.classify(Socket::IPAddress.new("192.0.0.50", 0))
      expect(block.try(&.name)).to eq("IETF Protocol Assignments")
      expect(block.try(&.prefix_length)).to eq(24)
      expect(block.try(&.rfc)).to eq("RFC 6890")
      expect(block.try(&.globally_reachable)).to be_false
    end

    it "returns 0.0.0.0/32 for the single address 0.0.0.0, not 0.0.0.0/8" do
      # both entries match 0.0.0.0. the /32 must win.
      block = described_class.classify(Socket::IPAddress.new("0.0.0.0", 0))
      expect(block.try(&.name)).to eq("This host on this network")
      expect(block.try(&.prefix_length)).to eq(32)
      expect(block.try(&.rfc)).to eq("RFC 1122")
    end

    it "returns 0.0.0.0/8 for non-zero addresses inside the /8" do
      block = described_class.classify(Socket::IPAddress.new("0.1.2.3", 0))
      expect(block.try(&.name)).to eq("This network")
      expect(block.try(&.prefix_length)).to eq(8)
      expect(block.try(&.rfc)).to eq("RFC 791")
    end

    it "returns the /32 Teredo entry for 2001::, not the /23 parent" do
      # 2001:: is inside both 2001::/23 and the /32 teredo carve-out.
      # the /32 must win.
      block = described_class.classify(Socket::IPAddress.new("2001::", 0))
      expect(block.try(&.name)).to eq("TEREDO")
      expect(block.try(&.prefix_length)).to eq(32)
      expect(block.try(&.rfc)).to eq("RFC 4380, RFC 8190")
      expect(block.try(&.globally_reachable)).to be_false
    end

    it "returns the /23 parent inside 2001::/23 but outside any carve-out" do
      # 2001:1ff::1 is inside the IETF protocol assignments /23 but
      # not inside any of the nested /28, /32, /48, or /128 entries.
      block = described_class.classify(Socket::IPAddress.new("2001:1ff::1", 0))
      expect(block.try(&.name)).to eq("IETF Protocol Assignments")
      expect(block.try(&.prefix_length)).to eq(23)
      expect(block.try(&.rfc)).to eq("RFC 2928")
      expect(block.try(&.globally_reachable)).to be_false
    end

    it "returns ::/128 for ::, ::1/128 for ::1, and ::/96 for embedded-IPv4 forms" do
      # ::/96 contains ::/128 and ::1/128; the /128s must win for
      # the exact addresses.
      block = described_class.classify(Socket::IPAddress.new("::127.0.0.1", 0))
      expect(block.try(&.name)).to eq("IPv4-Compatible IPv6 Address (deprecated)")
      expect(block.try(&.prefix_length)).to eq(96)

      block = described_class.classify(Socket::IPAddress.new("::", 0))
      expect(block.try(&.name)).to eq("Unspecified Address")
      expect(block.try(&.prefix_length)).to eq(128)

      block = described_class.classify(Socket::IPAddress.new("::1", 0))
      expect(block.try(&.name)).to eq("Loopback Address")
      expect(block.try(&.prefix_length)).to eq(128)
    end

    it "returns nil for unregistered addresses" do
      expect(described_class.classify(Socket::IPAddress.new("1.1.1.1", 0))).to be_nil
      expect(described_class.classify(Socket::IPAddress.new("2606:4700:4700::1111", 0))).to be_nil
    end
  end

  describe "application policy" do
    # verify that every address in V4_POLICY / V6_POLICY is rejected
    # via the policy path rather than the IANA-flag path -- i.e., the
    # classifier finds an IANA-globally-reachable entry that policy
    # then overrides. behavioral rejection itself is covered above;
    # this spec proves which path the rejection arrives through.

    it "rejects every V4_POLICY / V6_POLICY entry via the policy path" do
      [
        "192.0.0.9", "192.0.0.10", "192.31.196.0", "192.52.193.0", "192.175.48.0",
        "64:ff9b::", "2001:1::1", "2001:1::2", "2001:1::3", "2001:3::",
        "2001:4:112::", "2001:20::", "2001:30::", "2620:4f:8000::",
      ].each do |ip_str|
        addr = Socket::IPAddress.new(ip_str, 0)
        expect(described_class.classify(addr).try(&.globally_reachable)).to be_true, "expected #{ip_str} to classify as IANA-globally-reachable"
      end
    end
  end
end
