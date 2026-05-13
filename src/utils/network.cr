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

    # Resolves the hostname and checks the resulting IP address
    # against private and reserved ranges.
    #
    private def validate_host(host : String)
      addrinfos = Socket::Addrinfo.resolve(host, 443, type: Socket::Type::STREAM)
      raise Error.new("No addresses found: #{host}") if addrinfos.empty?
      addr = addrinfos.first.ip_address
      if addr.loopback? || addr.private? || addr.link_local? || addr.unspecified?
        raise Error.new("Request to private address denied: #{host}")
      end
    end

    # Fetches the specified URL via HTTP GET.
    #
    # When `key_pair` is supplied, the request is signed; pass `nil`
    # (or use the no-key-pair overload) for unsigned requests.
    #
    # Will automatically follow `attempts` redirects (default 10).
    #
    def get(key_pair, url, headers = HTTP::Headers.new, attempts = 10)
      was = url
      error_class = Error # default error class
      message = "Failed"
      attempts.times do
        start = Time.instant
        begin
          uri = URI.parse(url)
          host = uri.host.presence
          raise Error.new("URL has no host: #{url}") unless host
          unless uri.scheme == "http" || uri.scheme == "https"
            raise Error.new("URL scheme not supported: #{url}")
          end
          validate_host(host)
          client = HTTP::Client.new(uri)
          client.dns_timeout = 5.seconds
          client.connect_timeout = 5.seconds
          client.write_timeout = 5.seconds
          client.read_timeout = 5.seconds
          request_headers =
            if key_pair
              Ktistec::Signature.sign(key_pair, url, method: :get).merge!(headers)
            else
              headers.dup
            end
          request_headers["User-Agent"] = "ktistec/#{Ktistec::VERSION} (+https://github.com/toddsundsted/ktistec)"
          response = client.get(uri.request_target, request_headers)
          case response.status_code
          when 200
            return response
          when 301, 302, 303, 307, 308
            if (tmp = response.headers["Location"]?) && (url = uri.resolve(tmp).to_s)
              next
            else
              message = "Could not redirect [#{response.status_code}] [#{tmp}]"
              break
            end
          when 401, 403
            message = "Access denied [#{response.status_code}]"
            break
          when 404, 410
            error_class = NotFoundError
            message = "Does not exist [#{response.status_code}]"
            break
          when 500
            message = "Server error [#{response.status_code}]"
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

    # :ditto:
    def get(key_pair, url, headers = HTTP::Headers.new, attempts = 10, &)
      yield get(key_pair, url, headers, attempts)
    end

    # :ditto:
    def get(url : String | URI, headers = HTTP::Headers.new, attempts = 10)
      get(nil, url, headers, attempts)
    end

    # :ditto:
    def get(url : String | URI, headers = HTTP::Headers.new, attempts = 10, &)
      yield get(nil, url, headers, attempts)
    end

    # :ditto:
    def get?(key_pair, url, headers = HTTP::Headers.new, attempts = 10)
      get(key_pair, url, headers, attempts)
    rescue ex : Error
      Log.info { "#{self}.get? - #{ex.message}" }
    end

    # :ditto:
    def get?(key_pair, url, headers = HTTP::Headers.new, attempts = 10, &)
      yield get(key_pair, url, headers, attempts)
    rescue ex : Error
      Log.info { "#{self}.get? - #{ex.message}" }
    end

    # :ditto:
    def get?(url : String | URI, headers = HTTP::Headers.new, attempts = 10)
      get(nil, url, headers, attempts)
    rescue ex : Error
      Log.info { "#{self}.get? - #{ex.message}" }
    end

    # :ditto:
    def get?(url : String | URI, headers = HTTP::Headers.new, attempts = 10, &)
      yield get(nil, url, headers, attempts)
    rescue ex : Error
      Log.info { "#{self}.get? - #{ex.message}" }
    end

    class Error < Exception
    end

    # Raised when the response status is 404 or 410.
    #
    class NotFoundError < Error
    end
  end
end
