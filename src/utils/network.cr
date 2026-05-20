require "http"
require "socket"
require "uri"

require "../framework/signature"
require "./web_finger"

module Ktistec
  # Utilities for network operations.
  #
  module Network
    extend self

    Log = ::Log.for(self)

    {% if flag?(:allow_private_addresses) %}
      Log.warn { "Outbound HTTP permitted to 127.0.0.0/8, ::1/128, 172.16.0.0/12, 192.168.0.0/16" }
    {% end %}

    # An IPv4 IANA Special-Purpose Address Registry entry.
    #
    private record V4Block,
      network : UInt32,
      prefix_length : Int32,
      name : String,
      rfc : String,
      globally_reachable : Bool

    # An IPv6 IANA Special-Purpose Address Registry entry.
    #
    private record V6Block,
      network : UInt128,
      prefix_length : Int32,
      name : String,
      rfc : String,
      globally_reachable : Bool

    # Parses a dotted-quad string into a packed UInt32.
    #
    private def parse_v4_literal(s : String) : UInt32
      a, b, c, d = Socket::IPAddress.parse_v4_fields?(s).not_nil!
      (a.to_u32 << 24) | (b.to_u32 << 16) | (c.to_u32 << 8) | d.to_u32
    end

    # Parses an IPv6 string into a packed UInt128.
    #
    private def parse_v6_literal(s : String) : UInt128
      result = 0_u128
      fields = Socket::IPAddress.parse_v6_fields?(s).not_nil!
      fields.each { |f| result = (result << 16) | f.to_u128 }
      result
    end

    # IPv4 Special-Purpose Address Registry, transcribed from IANA
    # SPAR (https://www.iana.org/assignments/iana-ipv4-special-registry/)
    # with one local addition:
    #
    #   224.0.0.0/4 (Multicast, RFC 5771) -- not in SPAR but is not a
    #     valid HTTP unicast target.
    #
    private V4_REGISTRY = [
      V4Block.new(parse_v4_literal("0.0.0.0"), 8, "This network", "RFC 791", false),
      V4Block.new(parse_v4_literal("0.0.0.0"), 32, "This host on this network", "RFC 1122", false),
      V4Block.new(parse_v4_literal("10.0.0.0"), 8, "Private-Use", "RFC 1918", false),
      V4Block.new(parse_v4_literal("100.64.0.0"), 10, "Shared Address Space", "RFC 6598", false),
      V4Block.new(parse_v4_literal("127.0.0.0"), 8, "Loopback", "RFC 1122", false),
      V4Block.new(parse_v4_literal("169.254.0.0"), 16, "Link Local", "RFC 3927", false),
      V4Block.new(parse_v4_literal("172.16.0.0"), 12, "Private-Use", "RFC 1918", false),
      V4Block.new(parse_v4_literal("192.0.0.0"), 24, "IETF Protocol Assignments", "RFC 6890", false),
      V4Block.new(parse_v4_literal("192.0.0.0"), 29, "IPv4 Service Continuity Prefix", "RFC 7335", false),
      V4Block.new(parse_v4_literal("192.0.0.8"), 32, "IPv4 dummy address", "RFC 7600", false),
      V4Block.new(parse_v4_literal("192.0.0.9"), 32, "Port Control Protocol Anycast", "RFC 7723", true),
      V4Block.new(parse_v4_literal("192.0.0.10"), 32, "Traversal Using Relays around NAT Anycast", "RFC 8155", true),
      V4Block.new(parse_v4_literal("192.0.0.170"), 32, "NAT64/DNS64 Discovery", "RFC 8880", false),
      V4Block.new(parse_v4_literal("192.0.0.171"), 32, "NAT64/DNS64 Discovery", "RFC 8880", false),
      V4Block.new(parse_v4_literal("192.0.2.0"), 24, "Documentation (TEST-NET-1)", "RFC 5737", false),
      V4Block.new(parse_v4_literal("192.31.196.0"), 24, "AS112-v4", "RFC 7535", true),
      V4Block.new(parse_v4_literal("192.52.193.0"), 24, "AMT", "RFC 7450", true),
      V4Block.new(parse_v4_literal("192.88.99.0"), 24, "Deprecated (6to4 Relay Anycast)", "RFC 7526", false),
      V4Block.new(parse_v4_literal("192.88.99.2"), 32, "6a44-relay anycast address", "RFC 6751", false),
      V4Block.new(parse_v4_literal("192.168.0.0"), 16, "Private-Use", "RFC 1918", false),
      V4Block.new(parse_v4_literal("192.175.48.0"), 24, "Direct Delegation AS112 Service", "RFC 7534", true),
      V4Block.new(parse_v4_literal("198.18.0.0"), 15, "Benchmarking", "RFC 2544", false),
      V4Block.new(parse_v4_literal("198.51.100.0"), 24, "Documentation (TEST-NET-2)", "RFC 5737", false),
      V4Block.new(parse_v4_literal("203.0.113.0"), 24, "Documentation (TEST-NET-3)", "RFC 5737", false),
      V4Block.new(parse_v4_literal("224.0.0.0"), 4, "Multicast", "RFC 5771", false),
      V4Block.new(parse_v4_literal("240.0.0.0"), 4, "Reserved", "RFC 1112", false),
      V4Block.new(parse_v4_literal("255.255.255.255"), 32, "Limited Broadcast", "RFC 8190", false),
    ]

    # IPv6 Special-Purpose Address Registry, transcribed from IANA
    # SPAR (https://www.iana.org/assignments/iana-ipv6-special-registry/)
    # with two transformations:
    #
    #   IANA's "N/A" (Teredo, deprecated ORCHID, 6to4) are
    #     tunneling/deprecated mechanisms, not HTTP unicast targets.
    #   Two Ktistec-local additions not in current SPAR:
    #     * ::/96 (IPv4-Compatible IPv6, RFC 4291 §2.5.5.1) --
    #       deprecated in 2006 and removed from SPAR.
    #     * ff00::/8 (Multicast, RFC 4291) -- not a valid HTTP
    #       unicast target.
    #
    private V6_REGISTRY = [
      V6Block.new(parse_v6_literal("::"), 128, "Unspecified Address", "RFC 4291", false),
      V6Block.new(parse_v6_literal("::1"), 128, "Loopback Address", "RFC 4291", false),
      V6Block.new(parse_v6_literal("::"), 96, "IPv4-Compatible IPv6 Address (deprecated)", "RFC 4291", false),
      V6Block.new(parse_v6_literal("::ffff:0:0"), 96, "IPv4-mapped Address", "RFC 4291", false),
      V6Block.new(parse_v6_literal("64:ff9b::"), 96, "IPv4-IPv6 Translation", "RFC 6052", true),
      V6Block.new(parse_v6_literal("64:ff9b:1::"), 48, "IPv4-IPv6 Translation", "RFC 8215", false),
      V6Block.new(parse_v6_literal("100::"), 64, "Discard-Only Address Block", "RFC 6666", false),
      V6Block.new(parse_v6_literal("100:0:0:1::"), 64, "Dummy IPv6 Prefix", "RFC 9780", false),
      V6Block.new(parse_v6_literal("2001::"), 23, "IETF Protocol Assignments", "RFC 2928", false),
      V6Block.new(parse_v6_literal("2001::"), 32, "TEREDO", "RFC 4380, RFC 8190", false),
      V6Block.new(parse_v6_literal("2001:1::1"), 128, "Port Control Protocol Anycast", "RFC 7723", true),
      V6Block.new(parse_v6_literal("2001:1::2"), 128, "Traversal Using Relays around NAT Anycast", "RFC 8155", true),
      V6Block.new(parse_v6_literal("2001:1::3"), 128, "DNS-SD Service Registration Protocol Anycast", "RFC 9665", true),
      V6Block.new(parse_v6_literal("2001:2::"), 48, "Benchmarking", "RFC 5180", false),
      V6Block.new(parse_v6_literal("2001:3::"), 32, "AMT", "RFC 7450", true),
      V6Block.new(parse_v6_literal("2001:4:112::"), 48, "AS112-v6", "RFC 7535", true),
      V6Block.new(parse_v6_literal("2001:10::"), 28, "Deprecated (previously ORCHID)", "RFC 4843", false),
      V6Block.new(parse_v6_literal("2001:20::"), 28, "ORCHIDv2", "RFC 7343", true),
      V6Block.new(parse_v6_literal("2001:30::"), 28, "Drone Remote ID Protocol Entity Tags (DETs) Prefix", "RFC 9374", true),
      V6Block.new(parse_v6_literal("2001:db8::"), 32, "Documentation", "RFC 3849", false),
      V6Block.new(parse_v6_literal("2002::"), 16, "6to4", "RFC 3056", false),
      V6Block.new(parse_v6_literal("2620:4f:8000::"), 48, "Direct Delegation AS112 Service", "RFC 7534", true),
      V6Block.new(parse_v6_literal("3fff::"), 20, "Documentation", "RFC 9637", false),
      V6Block.new(parse_v6_literal("5f00::"), 16, "Segment Routing (SRv6) SIDs", "RFC 9602", false),
      V6Block.new(parse_v6_literal("fc00::"), 7, "Unique-Local", "RFC 4193, RFC 8190", false),
      V6Block.new(parse_v6_literal("fe80::"), 10, "Link-Local Unicast", "RFC 4291", false),
      V6Block.new(parse_v6_literal("ff00::"), 8, "Multicast", "RFC 4291", false),
    ]

    # Application policy: IANA-globally-reachable entries that Ktistec
    # still refuses outbound HTTP to. Each entry is keyed by the
    # registry block's network address.
    #
    #   192.0.0.9, 192.0.0.10 — Port Control Protocol / TURN anycast
    #     (RFC 7723, RFC 8155).
    #   192.31.196.0/24 — AS112-v4 (RFC 7535); reverse DNS service
    #     for private IPv4 ranges.
    #   192.52.193.0/24 — AMT (RFC 7450); IPv4 multicast tunneling.
    #   192.175.48.0/24 — Direct Delegation AS112 Service (RFC 7534).
    #
    private V4_POLICY = [
      parse_v4_literal("192.0.0.9"),
      parse_v4_literal("192.0.0.10"),
      parse_v4_literal("192.31.196.0"),
      parse_v4_literal("192.52.193.0"),
      parse_v4_literal("192.175.48.0"),
    ]

    # Permits outbound HTTP to IPv4 loopback and the two RFC 1918
    # ranges.
    #
    {% if flag?(:allow_private_addresses) %}
      private V4_ALLOWED_PRIVATE = [
        parse_v4_literal("127.0.0.0"),
        parse_v4_literal("172.16.0.0"),
        parse_v4_literal("192.168.0.0"),
      ]
    {% end %}

    # Application policy: IANA-globally-reachable entries that Ktistec
    # still refuses outbound HTTP to. Each entry is keyed by the
    # registry block's network address.
    #
    #   64:ff9b::/96 — NAT64 well-known prefix (RFC 6052); the low 32
    #     bits embed an attacker-chosen IPv4 destination at the v4
    #     translation layer.
    #   2001:1::1, 2001:1::2, 2001:1::3 — IPv6 PCP / TURN / DNS-SD
    #     anycast (RFC 7723, RFC 8155, RFC 9665).
    #   2001:3::/32 — AMT relay anycast (RFC 7450).
    #   2001:4:112::/48 — AS112-v6 service (RFC 7535).
    #   2001:20::/28 — ORCHIDv2 (RFC 7343); cryptographic host
    #     identity tags, not unicast destinations in the IP sense.
    #   2001:30::/28 — Drone Remote ID Protocol Entity Tags (RFC 9374);
    #     entity identifiers, not HTTP endpoints.
    #   2620:4f:8000::/48 — Direct Delegation AS112 Service (RFC 7534).
    #
    private V6_POLICY = [
      parse_v6_literal("64:ff9b::"),
      parse_v6_literal("2001:1::1"),
      parse_v6_literal("2001:1::2"),
      parse_v6_literal("2001:1::3"),
      parse_v6_literal("2001:3::"),
      parse_v6_literal("2001:4:112::"),
      parse_v6_literal("2001:20::"),
      parse_v6_literal("2001:30::"),
      parse_v6_literal("2620:4f:8000::"),
    ]

    # Permits outbound HTTP to IPv6 loopback.
    #
    {% if flag?(:allow_private_addresses) %}
      private V6_ALLOWED_PRIVATE = [
        parse_v6_literal("::1"),
      ]
    {% end %}

    # Returns true if `addr` is a destination Ktistec is willing to
    # send outbound HTTP to on behalf of untrusted (federated) input.
    #
    # Looks up `addr` in the IANA Special-Purpose Address Registry
    # and applies Ktistec's SSRF policy to the most-specific match:
    #
    #   - No match: address is in unallocated/globally-reachable
    #     space per IANA convention → allow.
    #   - Matched entry's `globally_reachable` is false → reject.
    #   - Matched entry's `globally_reachable` is true but the entry
    #     is in the application policy set → reject.
    #   - Otherwise → allow.
    #
    def safe_for_untrusted_outbound_http?(addr : Socket::IPAddress) : Bool
      block = classify(addr)
      case block
      in Nil
        true
      in V4Block
        (block.globally_reachable && !V4_POLICY.includes?(block.network)) || dev_permits?(addr, block)
      in V6Block
        (block.globally_reachable && !V6_POLICY.includes?(block.network)) || dev_permits?(addr, block)
      end
    end

    # Permits outbound HTTP to a narrow set of private/loopback ranges
    # that cover common federation testing and development scenarios.
    #
    {% if flag?(:allow_private_addresses) %}
      private def dev_permits?(addr : Socket::IPAddress, block : V4Block) : Bool
        return false unless V4_ALLOWED_PRIVATE.includes?(block.network)
        Log.debug { "Outbound HTTP to #{addr.address} permitted (#{block.name}, #{block.rfc})" }
        true
      end

      private def dev_permits?(addr : Socket::IPAddress, block : V6Block) : Bool
        return false unless V6_ALLOWED_PRIVATE.includes?(block.network)
        Log.debug { "Outbound HTTP to #{addr.address} permitted (#{block.name}, #{block.rfc})" }
        true
      end
    {% else %}
      private def dev_permits?(addr : Socket::IPAddress, block : V4Block) : Bool
        false
      end

      private def dev_permits?(addr : Socket::IPAddress, block : V6Block) : Bool
        false
      end
    {% end %}

    # Returns the most-specific IANA Special-Purpose Address Registry
    # entry containing `addr`, or `nil` if `addr` is not in any
    # registered block.
    #
    private def classify(addr : Socket::IPAddress) : (V4Block | V6Block)?
      case addr.family
      when Socket::Family::INET
        lookup_v4(parse_v4_literal(addr.address))
      when Socket::Family::INET6
        lookup_v6(parse_v6_literal(addr.address))
      end
    end

    private def lookup_v4(addr : UInt32) : V4Block?
      best : V4Block? = nil
      V4_REGISTRY.each do |block|
        mask = block.prefix_length == 0 ? 0_u32 : (UInt32::MAX << (32 - block.prefix_length))
        if (addr & mask) == block.network && (best.nil? || block.prefix_length > best.prefix_length)
          best = block
        end
      end
      best
    end

    private def lookup_v6(addr : UInt128) : V6Block?
      best : V6Block? = nil
      V6_REGISTRY.each do |block|
        mask = block.prefix_length == 0 ? 0_u128 : (UInt128::MAX << (128 - block.prefix_length))
        if (addr & mask) == block.network && (best.nil? || block.prefix_length > best.prefix_length)
          best = block
        end
      end
      best
    end

    # Resolves the name of a resource to the network IRI of the
    # resource.
    #
    # Returns the IRI if successful. Raises an error if things go wrong:
    #
    #   Ktistec::HostMeta::Error, Ktistec::WebFinger::Error - the underlying lookup failed
    #
    #   KeyError - a rel="self" link does not exist in the retrieved record
    #
    #   NilAssertionError - the href attribute is blank
    #
    def self.resolve(name)
      url = URI.parse(name)
      if url.scheme && (host = url.host) && (path = url.path)
        if path =~ /^\/@([a-zA-Z0-9_]+)\/?$/
          Ktistec::WebFinger.query("acct:#{$1}@#{host}").link("self").href.presence.not_nil!
        else
          name
        end
      else
        Ktistec::WebFinger.query("acct:#{name.lchop('@')}").link("self").href.presence.not_nil!
      end
    end

    DNS_TIMEOUT     = 5.seconds
    CONNECT_TIMEOUT = 5.seconds
    READ_TIMEOUT    = 5.seconds
    WRITE_TIMEOUT   = 5.seconds

    # Resolves `host` on `port` with a DNS timeout, validates every
    # returned address against the SSRF policy, and returns the first
    # validated `Addrinfo`.
    #
    private def resolve_and_validate(host : String, port : Int32) : Socket::Addrinfo
      addrinfos = Socket::Addrinfo.tcp(host, port, timeout: DNS_TIMEOUT)
      raise Error.new("No addresses found: #{host}") if addrinfos.empty?
      addrinfos.each do |addrinfo|
        unless safe_for_untrusted_outbound_http?(addrinfo.ip_address)
          raise Error.new("Request to private address denied: #{host}")
        end
      end
      addrinfos.first
    end

    # Opens a TCP socket to the specified `Addrinfo` and, for HTTPS,
    # wraps it in a TLS layer using the URL hostname for SNI and
    # peer-certificate verification.
    #
    private def open_socket(uri : URI, addrinfo : Socket::Addrinfo) : IO
      tcp = TCPSocket.new(addrinfo.family)
      begin
        tcp.connect(addrinfo, timeout: CONNECT_TIMEOUT)
      rescue ex
        tcp.close
        raise ex
      end
      tcp.read_timeout = READ_TIMEOUT
      tcp.write_timeout = WRITE_TIMEOUT
      tcp.sync = false
      if uri.scheme == "https"
        begin
          OpenSSL::SSL::Socket::Client.new(
            tcp,
            context: OpenSSL::SSL::Context::Client.new,
            sync_close: true,
            hostname: uri.host.not_nil!,
          )
        rescue ex
          tcp.close
          raise ex
        end
      else
        tcp
      end
    end

    private def make_client(uri : URI) : HTTP::Client
      host = uri.host.not_nil!
      port = uri.port || (uri.scheme == "https" ? 443 : 80)
      addrinfo = resolve_and_validate(host, port)
      io = open_socket(uri, addrinfo)
      HTTP::Client.new(io: io, host: host, port: port)
    end

    MAX_GET_RESPONSE_BYTES = 1_048_576

    MAX_DISCOVERY_RESPONSE_BYTES = 65_536

    # Fetches the specified URL via HTTP GET.
    #
    # When `key_pair` is supplied, the request is signed; pass `nil`
    # (or use the no-key-pair overload) for unsigned requests.
    #
    # Will automatically follow `attempts` redirects (default 10).
    #
    # The response body is capped at `max_bytes`; responses whose
    # `Content-Length` exceeds the cap are rejected before any body
    # bytes are read, and streamed bodies are aborted if they grow
    # past the cap.
    #
    def get(key_pair, url, headers = HTTP::Headers.new, attempts = 10, *, max_bytes : Int32 = MAX_GET_RESPONSE_BYTES)
      was = url
      error_class = Error # default error class
      message = "Failed"
      attempts.times do
        start = Time.instant
        client = nil
        begin
          uri = URI.parse(url)
          host = uri.host.presence
          raise Error.new("URL has no host: #{url}") unless host
          unless uri.scheme == "http" || uri.scheme == "https"
            raise Error.new("URL scheme not supported: #{url}")
          end
          client = make_client(uri)
          request_headers =
            if key_pair
              Ktistec::Signature.sign(key_pair, url, method: :get).merge!(headers)
            else
              headers.dup
            end
          request_headers["User-Agent"] = "ktistec/#{Ktistec::VERSION} (+https://github.com/toddsundsted/ktistec)"
          # set Host explicitly to match what Signature.sign covered
          # (`url.authority`). the IO-bound HTTP::Client constructor used
          # by `make_client` does not carry TLS state, so its default
          # Host header would append `:443` on HTTPS default-port URLs
          # and break signature verification at the receiver.
          request_headers["Host"] = uri.authority.not_nil!
          status_code = 0
          response_headers = HTTP::Headers.new
          body_capped = ""
          client.get(uri.request_target, request_headers) do |response|
            status_code = response.status_code
            response_headers = response.headers
            if status_code == 200
              if (cl = response_headers["Content-Length"]?) && (n = cl.to_i?) && n > max_bytes
                raise Error.new("Response body too large [Content-Length=#{n} > #{max_bytes}]: #{url}")
              end
              if (io = response.body_io?)
                body_capped = read_strict_capped(io, max_bytes, url)
              end
            end
          end
          case status_code
          when 200
            status = HTTP::Status.new(status_code)
            return HTTP::Client::Response.new(status, body: body_capped, headers: response_headers)
          when 301, 302, 303, 307, 308
            if (tmp = response_headers["Location"]?) && (url = uri.resolve(tmp).to_s)
              next
            else
              message = "Could not redirect [#{status_code}] [#{tmp}]"
              break
            end
          when 401
            message = "Unauthorized [#{status_code}]"
            break
          when 403
            message = "Forbidden [#{status_code}]"
            break
          when 404, 410
            error_class = NotFoundError
            message = "Does not exist [#{status_code}]"
            break
          when 500
            message = "Server error [#{status_code}]"
            break
          else
            break
          end
        rescue URI::Error
          message = "Invalid URI"
          break
        rescue Socket::Addrinfo::Error
          message = "Hostname lookup failure"
          break
        rescue Socket::ConnectError
          message = "Connection failure"
          break
        rescue OpenSSL::Error
          message = "Secure connection failure"
          break
        rescue IO::TimeoutError # subclass of IO::Error
          message = "Timeout [#{(Time.instant - start).to_i}s]"
          break
        rescue IO::Error
          message = "I/O error"
          break
        rescue Compress::Deflate::Error | Compress::Gzip::Error
          message = "Encoding error"
          break
        ensure
          client.try(&.close)
        end
      end
      message =
        if was != url
          "#{message}: #{was} [from #{url}]"
        else
          "#{message}: #{was}"
        end
      raise error_class.new(message)
    end

    # Reads up to `max` bytes from `io` into a String. Raises if `io`
    # has more bytes available past the limit.
    #
    private def read_strict_capped(io : IO, max : Int32, url) : String
      buf = IO::Memory.new
      bytes = IO.copy(io, buf, max + 1)
      if bytes > max
        raise Error.new("Response body too large [>#{max} bytes]: #{url}")
      end
      buf.to_s
    end

    # :ditto:
    def get(key_pair, url, headers = HTTP::Headers.new, attempts = 10, *, max_bytes : Int32 = MAX_GET_RESPONSE_BYTES, &)
      yield get(key_pair, url, headers, attempts, max_bytes: max_bytes)
    end

    # :ditto:
    def get(url : String | URI, headers = HTTP::Headers.new, attempts = 10, *, max_bytes : Int32 = MAX_GET_RESPONSE_BYTES)
      get(nil, url, headers, attempts, max_bytes: max_bytes)
    end

    # :ditto:
    def get(url : String | URI, headers = HTTP::Headers.new, attempts = 10, *, max_bytes : Int32 = MAX_GET_RESPONSE_BYTES, &)
      yield get(nil, url, headers, attempts, max_bytes: max_bytes)
    end

    # :ditto:
    def get?(key_pair, url, headers = HTTP::Headers.new, attempts = 10, *, max_bytes : Int32 = MAX_GET_RESPONSE_BYTES)
      get(key_pair, url, headers, attempts, max_bytes: max_bytes)
    rescue ex : Error
      Log.info { "#{self}.get? - #{ex.message}" }
    end

    # :ditto:
    def get?(key_pair, url, headers = HTTP::Headers.new, attempts = 10, *, max_bytes : Int32 = MAX_GET_RESPONSE_BYTES, &)
      yield get(key_pair, url, headers, attempts, max_bytes: max_bytes)
    rescue ex : Error
      Log.info { "#{self}.get? - #{ex.message}" }
    end

    # :ditto:
    def get?(url : String | URI, headers = HTTP::Headers.new, attempts = 10, *, max_bytes : Int32 = MAX_GET_RESPONSE_BYTES)
      get(nil, url, headers, attempts, max_bytes: max_bytes)
    rescue ex : Error
      Log.info { "#{self}.get? - #{ex.message}" }
    end

    # :ditto:
    def get?(url : String | URI, headers = HTTP::Headers.new, attempts = 10, *, max_bytes : Int32 = MAX_GET_RESPONSE_BYTES, &)
      yield get(nil, url, headers, attempts, max_bytes: max_bytes)
    rescue ex : Error
      Log.info { "#{self}.get? - #{ex.message}" }
    end

    MAX_POST_RESPONSE_BYTES = 4096

    # Sends a HTTP POST to the specified URL.
    #
    # Signs the request internally with `key_pair`.
    #
    # The returned response carries up to `MAX_POST_RESPONSE_BYTES` of
    # the response body.
    #
    # Does not follow redirects.
    #
    def post(key_pair, url : String, body : String, content_type : String, headers = HTTP::Headers.new) : HTTP::Client::Response
      start = Time.instant
      client = nil
      begin
        uri = URI.parse(url)
        host = uri.host.presence
        raise Error.new("URL has no host: #{url}") unless host
        unless uri.scheme == "http" || uri.scheme == "https"
          raise Error.new("URL scheme not supported: #{url}")
        end
        client = make_client(uri)
        request_headers = Ktistec::Signature.sign(key_pair, url, body, content_type).merge!(headers)
        request_headers["User-Agent"] = "ktistec/#{Ktistec::VERSION} (+https://github.com/toddsundsted/ktistec)"
        # set Host explicitly to match what Signature.sign covered
        # (`url.authority`). See `.get` above.
        status_code = 0
        request_headers["Host"] = uri.authority.not_nil!
        response_headers = HTTP::Headers.new
        snippet = ""
        client.post(uri.request_target, request_headers, body) do |response|
          status_code = response.status_code
          response_headers = response.headers
          # body_io is absent on no-body statuses (e.g., 204, 304).
          if (io = response.body_io?)
            snippet = read_capped(io, MAX_POST_RESPONSE_BYTES)
          end
        end
        status = HTTP::Status.new(status_code)
        if HTTP::Client::Response.mandatory_body?(status)
          HTTP::Client::Response.new(status, body: snippet, headers: response_headers)
        else
          HTTP::Client::Response.new(status, headers: response_headers)
        end
      rescue URI::Error
        raise Error.new("Invalid URI: #{url}")
      rescue Socket::Addrinfo::Error
        raise Error.new("Hostname lookup failure: #{url}")
      rescue Socket::ConnectError
        raise Error.new("Connection failure: #{url}")
      rescue OpenSSL::Error
        raise Error.new("Secure connection failure: #{url}")
      rescue IO::TimeoutError # subclass of IO::Error
        raise Error.new("Timeout [#{(Time.instant - start).to_i}s]: #{url}")
      rescue IO::Error
        raise Error.new("I/O error: #{url}")
      rescue Compress::Deflate::Error | Compress::Gzip::Error
        raise Error.new("Encoding error: #{url}")
      ensure
        client.try(&.close)
      end
    end

    # Reads up to `max` bytes from `io` into a new String, leaving any
    # remaining bytes unread.
    #
    private def read_capped(io : IO, max : Int32) : String
      buf = IO::Memory.new
      IO.copy(io, buf, max)
      buf.to_s
    end

    class Error < Exception
    end

    # Raised when the response status is 404 or 410.
    #
    class NotFoundError < Error
    end
  end
end
