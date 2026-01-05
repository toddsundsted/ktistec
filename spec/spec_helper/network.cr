require "spectator"
require "http/request"

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
    @cache = Hash(String, String).new

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

  def self.get(url : String | URI, headers : HTTP::Headers? = nil)
    url = URI.parse(url) if url.is_a?(String)
    new(url).get(url.request_target, headers)
  end

  def get(path : String, headers : HTTP::Headers? = nil)
    url = URI.new(scheme: "https", host: self.host, path: path)
    @@requests << HTTP::Request.new("GET", url.to_s, headers)
    if url.scheme && url.authority && url.path
      case url.path
      when /bad-json/
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "bad json"
        )
      when /specified-page/
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: "content"
        )
      when /redirected-page-absolute/
        HTTP::Client::Response.new(
          301,
          headers: HTTP::Headers{"Location" => "https://#{url.host}/specified-page"},
          body: ""
        )
      when /redirected-page-relative/
        HTTP::Client::Response.new(
          301,
          headers: HTTP::Headers{"Location" => "/specified-page"},
          body: ""
        )
      when /redirected-no-location/
        HTTP::Client::Response.new(
          301,
          headers: HTTP::Headers.new,
          body: ""
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
          body: $1
        )
      else
        if (json = @@cache[url.to_s]?)
          HTTP::Client::Response.new(
            200,
            headers: HTTP::Headers.new,
            body: json
          )
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
      when /openssl-error/
        raise OpenSSL::Error.new
      when /io-error/
        raise IO::Error.new
      when /([^\/]+)\/inbox/
        HTTP::Client::Response.new(
          200,
          headers: HTTP::Headers.new,
          body: ""
        )
      else
        if (json = @@cache[url.to_s]?)
          HTTP::Client::Response.new(
            200,
            headers: HTTP::Headers.new,
            body: json
          )
        else
          HTTP::Client::Response.new(404)
        end
      end
    else
      HTTP::Client::Response.new(500)
    end
  end
end

{% if @top_level.has_constant?("BEFORE_PROCS") %}
  BEFORE_PROCS << -> do
    HTTP::Client.reset
  end
{% end %}

# WebFinger mock.
#
module WebFinger
  ACCOUNT_REGEX = %r<
    ^(acct:)?(?<name>[^@]+)@(?<host>[^@]+)$|
    ^(?<host>.+)$
  >mx

  def self.query(account)
    unless account =~ ACCOUNT_REGEX
      raise WebFinger::NotFoundError.new("Invalid account")
    end
    name = $~["name"]?
    host = $~["host"]
    if name =~ /no-such-name/
      raise WebFinger::NotFoundError.new("No such name")
    elsif host =~ /no-such-host/
      raise WebFinger::NotFoundError.new("No such host")
    elsif name
      WebFinger::Result.from_json(<<-JSON
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
      WebFinger::Result.from_json(<<-JSON
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
