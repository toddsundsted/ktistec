require "spectator"
require "http/request"
require "socket"

require "../../src/utils/web_finger"

require "./base"

# DNS resolution mock.
#
# Returns a public IP for most test hostnames. Hostnames matching the
# following patterns resolve to addresses in reserved ranges:
#
#   "loopback"    -> 127.0.0.1   (loopback)
#   "private-ip"  -> 10.0.0.1    (RFC 1918 private)
#   "link-local"  -> 169.254.0.1 (link-local)
#   "unspecified" -> 0.0.0.0     (unspecified)
#
# The "multi-answer-mixed" hostname resolves to a public address
# followed by a private one.
#
# Hostnames matching "socket-addrinfo-error" raise an error.
#
struct Socket::Addrinfo
  def self.resolve(domain : String, service, family : Family? = nil, type : Type = nil, protocol : Protocol = Protocol::IP, timeout = nil) : Array(Addrinfo)
    # implementation note: `previous_def` calls the real stdlib
    # resolver, which delegates to `getaddrinfo(3)`. POSIX specifies
    # that when the node string parses as a numeric IP address, no DNS
    # lookup is performed--the call is a local string-to-Addrinfo
    # conversion.
    if domain =~ /multi-answer-mixed/
      return previous_def("93.184.216.34", service, family, type, protocol, timeout) +
        previous_def("10.0.0.1", service, family, type, protocol, timeout)
    end
    ip = case domain
         when /socket-addrinfo-error/
           raise Socket::Addrinfo::Error.from_os_error(nil, nil)
         when /loopback/
           "127.0.0.1"
         when /private-ip/
           "10.0.0.1"
         when /link-local/
           "169.254.0.1"
         when /unspecified/
           "0.0.0.0"
         else
           "93.184.216.34"
         end
    previous_def(ip, service, family, type, protocol, timeout)
  end
end

# Networking mock.
#
# Cache an actor for later retrieval from the mock:
# `HTTP::Client.actors << ActivityPub::Actor.new(...`
#
# Fetch the last request sent to the mock:
# `Http::Client.last`
#
# Match the last request as a string:
# `expect(...last).to match("GET /foo/bar")`
#
class HTTP::Client
  class Cache
    @cache = Hash(String, String | HTTP::Client::Response).new

    delegate :[], :[]?, :[]=, :clear, :delete, to: @cache

    def <<(object)
      if object.responds_to?(:iri) && object.responds_to?(:to_json_ld)
        self[object.iri] = object.to_json_ld(recursive: true)
      else
        raise "Unsupported: #{object}"
      end
    end

    def set(url : String | URI, object)
      if object.responds_to?(:to_json)
        self[url.to_s] = object.to_json
      else
        raise "Unsupported: #{object}"
      end
    end

    def set_response(url : String | URI, response : HTTP::Client::Response)
      self[url.to_s] = response
    end
  end

  @@requests = [] of HTTP::Request

  @@cache = Cache.new

  def self.last?
    @@requests.last?
  end

  def self.requests
    @@requests
  end

  def self.cache
    @@cache
  end

  def self.activities
    @@cache
  end

  def self.collections
    @@cache
  end

  def self.actors
    @@cache
  end

  def self.objects
    @@cache
  end

  def self.reset
    @@requests.clear
    @@cache.clear
  end

  # Note: Short-circuit client instantiation to avoid costly and
  # unnecessary construction.

  def initialize(uri : URI)
    @host = uri.host.not_nil!
    @port = uri.port || 80
  end

  def initialize(io : IO, host : String = "", port : Int32 = 80)
    @host = host
    @port = port
  end

  def self.get(url : String | URI, headers : HTTP::Headers? = nil)
    url = URI.parse(url) if url.is_a?(String)
    new(url).get(url.request_target, headers)
  end

  def get(path : String, headers : HTTP::Headers? = nil)
    url = URI.new(scheme: "https", host: self.host, path: path)
    @@requests << HTTP::Request.new("GET", url.to_s, headers)
    case self.host
    when /socket-addrinfo-error/
      raise Socket::Addrinfo::Error.from_os_error(nil, nil)
    when /socket-connect-error/
      raise Socket::ConnectError.from_os_error(nil, nil)
    end
    if url.scheme && url.authority && url.path
      case url.path
      when /bad-json/
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "bad json",
        )
      when /specified-page/
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "content",
        )
      when /redirected-page-absolute/
        HTTP::Client::Response.new(
          301,
          headers: HTTP::Headers{"Location" => "https://#{url.host}/specified-page"},
          body: "",
        )
      when /redirected-page-relative/
        HTTP::Client::Response.new(
          301,
          headers: HTTP::Headers{"Location" => "/specified-page"},
          body: "",
        )
      when /redirected-no-location/
        HTTP::Client::Response.new(
          301,
          headers: HTTP::Headers.new,
          body: "",
        )
      when /socket-addrinfo-error/
        raise Socket::Addrinfo::Error.from_os_error(nil, nil)
      when /socket-connect-error/
        raise Socket::ConnectError.from_os_error(nil, nil)
      when /openssl-error/
        raise OpenSSL::Error.new
      when /io-error/
        raise IO::Error.new
      when /returns-([0-9]{3})/
        HTTP::Client::Response.new(
          $1.to_i,
          headers: HTTP::Headers.new,
          body: $1,
        )
      else
        if (stub = @@cache[url.to_s]?)
          case stub
          in HTTP::Client::Response
            stub
          in String
            HTTP::Client::Response.new(
              200,
              headers: HTTP::Headers.new,
              body: stub,
            )
          end
        else
          HTTP::Client::Response.new(404)
        end
      end
    else
      HTTP::Client::Response.new(500)
    end
  end

  def self.post(url : String | URI, headers : HTTP::Headers, body : String)
    url = URI.parse(url) if url.is_a?(String)
    new(url).post(url.request_target, headers, body)
  end

  def post(path : String, headers : HTTP::Headers, body : String)
    url = URI.new(scheme: "https", host: self.host, path: path)
    @@requests << HTTP::Request.new("POST", url.to_s, headers, body)
    if url.scheme && url.authority && url.path
      case url.path
      when /socket-addrinfo-error/
        raise Socket::Addrinfo::Error.from_os_error(nil, nil)
      when /socket-connect-error/
        raise Socket::ConnectError.from_os_error(nil, nil)
      when /openssl-error/
        raise OpenSSL::Error.new
      when /io-error/
        raise IO::Error.new
      when /([^\/]+)\/inbox/
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "",
        )
      else
        if (stub = @@cache[url.to_s]?)
          case stub
          in HTTP::Client::Response
            stub
          in String
            HTTP::Client::Response.new(
              200,
              headers: HTTP::Headers.new,
              body: stub,
            )
          end
        else
          HTTP::Client::Response.new(404)
        end
      end
    else
      HTTP::Client::Response.new(500)
    end
  end

  def post(path : String, headers : HTTP::Headers, body : String, &)
    response = post(path, headers, body)
    # mimic streaming form: yield a response with body_io populated
    # instead of body, matching what Crystal's real HTTP::Client does.
    # statuses that disallow a body (e.g. 204) get yielded as-is, since
    # HTTP::Client::Response refuses to be constructed with body_io on
    # those statuses.
    streaming =
      if HTTP::Client::Response.mandatory_body?(response.status)
        HTTP::Client::Response.new(
          response.status_code,
          headers: response.headers,
          body_io: IO::Memory.new(response.body),
        )
      else
        response
      end
    yield streaming
  end
end

BEFORE_PROCS << -> do
  HTTP::Client.reset
  Ktistec::Network.reset_last_addrinfo
end

# test override: records the passed `Addrinfo` so specs can verify it
# matches what the resolver produced.
#
module Ktistec
  module Network
    @@last_addrinfo : Socket::Addrinfo? = nil

    def self.last_addrinfo
      @@last_addrinfo
    end

    def self.reset_last_addrinfo
      @@last_addrinfo = nil
    end

    private def open_socket(uri : URI, addrinfo : Socket::Addrinfo) : IO
      @@last_addrinfo = addrinfo
      IO::Memory.new
    end
  end
end

# Ktistec::WebFinger mock.
#
module Ktistec
  module WebFinger
    ACCOUNT_REGEX = %r<
      ^(acct:)?(?<name>[^@]+)@(?<host>[^@]+)$|
      ^(?<host>.+)$
    >mx

    def self.query(account)
      unless account =~ ACCOUNT_REGEX
        raise Ktistec::WebFinger::NotFoundError.new("Invalid account")
      end
      name = $~["name"]?
      host = $~["host"]
      if name =~ /no-such-name/
        raise Ktistec::WebFinger::NotFoundError.new("No such name")
      elsif host =~ /no-such-host/
        raise Ktistec::WebFinger::NotFoundError.new("No such host")
      elsif name
        Ktistec::WebFinger::Result.from_json(<<-JSON
          {
            "links":[
              {
                "rel":"self",
                "href":"https://#{host}/actors/#{name}"
              },
              {
                "rel":"http://ostatus.org/schema/1.0/subscribe",
                "template":"https://#{host}/authorize-interaction?uri={uri}"
              }
            ]
          }
          JSON
        )
      else
        Ktistec::WebFinger::Result.from_json(<<-JSON
          {
            "links":[
              {
                "rel":"self",
                "href":"https://#{host}"
              },
              {
                "rel":"http://ostatus.org/schema/1.0/subscribe",
                "template":"https://#{host}/authorize-interaction?uri={uri}"
              }
            ]
          }
          JSON
        )
      end
    end
  end
end
